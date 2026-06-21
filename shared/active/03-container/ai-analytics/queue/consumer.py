"""
Message queue consumer for AI analytics pipeline.

This module implements the consumer that reads analytics events
from Redis Streams and processes them through the worker pool.
"""

import logging
import time
import threading
from typing import Optional, List, Dict, Any
from dataclasses import dataclass

from redis_client import RedisClient, RedisConnectionError
from config import QueueSystemConfig
from serialization import MessageSerializer
from metrics import QueueMetricsCollector
from errors import (
    QueueError,
    QueueConnectionError,
    QueueDeserializationError,
    QueueConsumerGroupError
)

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from collectors import AnalyticsEvent

logger = logging.getLogger(__name__)


@dataclass
class ConsumerMessage:
    """Message consumed from Redis Stream."""
    message_id: str
    event: AnalyticsEvent
    retry_count: int = 0


class QueueConsumer:
    """
    Consumer for reading analytics events from Redis Streams.
    
    This consumer:
    - Reads messages from Redis Streams using consumer groups
    - Supports batch processing for efficiency
    - Handles message acknowledgment
    - Routes failed messages to dead letter queue
    - Provides blocking reads with timeout
    """
    
    def __init__(
        self,
        config: QueueSystemConfig,
        consumer_name: str,
        metrics: Optional[QueueMetricsCollector] = None
    ):
        """
        Initialize queue consumer.
        
        Args:
            config: QueueSystemConfig instance
            consumer_name: Unique name for this consumer instance
            metrics: Optional metrics collector
        """
        self.config = config
        self.consumer_name = consumer_name
        self._redis_client: Optional[RedisClient] = None
        self._serializer = MessageSerializer(max_message_size=config.queue.max_message_size)
        self._metrics = metrics or QueueMetricsCollector()
        self._is_connected = False
        self._is_running = False
        self._stop_event = threading.Event()
        
    def connect(self) -> bool:
        """
        Connect to Redis and verify consumer group.
        
        Returns:
            True if connection successful, False otherwise
        """
        try:
            self._redis_client = RedisClient(self.config.redis)
            
            if not self._redis_client.connect():
                raise QueueConnectionError("Failed to connect to Redis")
            
            # Verify consumer group exists
            self._verify_consumer_group()
            
            self._is_connected = True
            logger.info(f"Queue consumer '{self.consumer_name}' connected to Redis")
            return True
            
        except Exception as e:
            logger.error(f"Failed to connect queue consumer: {e}")
            self._is_connected = False
            return False
    
    def disconnect(self):
        """Disconnect from Redis."""
        if self._redis_client:
            self._redis_client.disconnect()
            self._is_connected = False
            logger.info(f"Queue consumer '{self.consumer_name}' disconnected")
    
    def _verify_consumer_group(self):
        """Verify that consumer group exists."""
        try:
            # Get consumer group info
            info = self._redis_client.execute_command(
                'XINFO', 'GROUPS', self.config.queue.stream_name
            )
            
            group_names = [group['name'] for group in info]
            if self.config.queue.consumer_group not in group_names:
                raise QueueConsumerGroupError(
                    f"Consumer group '{self.config.queue.consumer_group}' not found"
                )
            
            logger.debug(f"Verified consumer group: {self.config.queue.consumer_group}")
            
        except QueueConsumerGroupError:
            raise
        except Exception as e:
            logger.warning(f"Could not verify consumer group: {e}")
    
    def read_messages(self, count: int = None, block: bool = True) -> List[ConsumerMessage]:
        """
        Read messages from Redis Stream.
        
        Args:
            count: Number of messages to read (default from config)
            block: Whether to block waiting for messages
            
        Returns:
            List of ConsumerMessage objects
        """
        if not self._is_connected:
            raise QueueConnectionError("Consumer not connected")
        
        if count is None:
            count = self.config.queue.batch_size
        
        try:
            if block:
                # Blocking read with timeout
                messages = self._redis_client.execute_command(
                    'XREADGROUP', 'GROUP',
                    self.config.queue.consumer_group,
                    self.consumer_name,
                    'COUNT', str(count),
                    'BLOCK', str(self.config.queue.block_timeout_ms),
                    'STREAMS', self.config.queue.stream_name, '>'
                )
            else:
                # Non-blocking read
                messages = self._redis_client.execute_command(
                    'XREADGROUP', 'GROUP',
                    self.config.queue.consumer_group,
                    self.consumer_name,
                    'COUNT', str(count),
                    'STREAMS', self.config.queue.stream_name, '>'
                )
            
            if not messages:
                return []
            
            # Parse messages
            consumer_messages = []
            for stream_name, stream_messages in messages:
                for message_id, fields in stream_messages:
                    try:
                        json_str = fields[b'data'] if isinstance(fields, dict) else fields['data']
                        if isinstance(json_str, bytes):
                            json_str = json_str.decode('utf-8')
                        
                        event = self._serializer.deserialize(json_str)
                        consumer_messages.append(
                            ConsumerMessage(message_id=message_id.decode(), event=event)
                        )
                        
                    except QueueDeserializationError as e:
                        logger.error(f"Failed to deserialize message {message_id}: {e}")
                        # Acknowledge to remove from pending
                        self.acknowledge_message(message_id)
                    except Exception as e:
                        logger.error(f"Error processing message {message_id}: {e}")
            
            # Update metrics
            if consumer_messages:
                self._metrics.record_consumed(len(consumer_messages))
            
            return consumer_messages
            
        except RedisConnectionError as e:
            logger.error(f"Connection error reading messages: {e}")
            self._is_connected = False
            raise
        except Exception as e:
            logger.error(f"Error reading messages: {e}")
            raise
    
    def acknowledge_message(self, message_id: str) -> bool:
        """
        Acknowledge successful processing of a message.
        
        Args:
            message_id: ID of message to acknowledge
            
        Returns:
            True if acknowledged successfully, False otherwise
        """
        try:
            self._redis_client.execute_command(
                'XACK', self.config.queue.stream_name,
                self.config.queue.consumer_group, message_id
            )
            logger.debug(f"Acknowledged message {message_id}")
            return True
        except Exception as e:
            logger.error(f"Failed to acknowledge message {message_id}: {e}")
            return False
    
    def acknowledge_batch(self, message_ids: List[str]) -> int:
        """
        Acknowledge multiple messages in a batch.
        
        Args:
            message_ids: List of message IDs to acknowledge
            
        Returns:
            Number of messages successfully acknowledged
        """
        success_count = 0
        for message_id in message_ids:
            if self.acknowledge_message(message_id):
                success_count += 1
        return success_count
    
    def send_to_dead_letter(self, message_id: str, error: str) -> bool:
        """
        Send failed message to dead letter queue.
        
        Args:
            message_id: ID of message to send to DLQ
            error: Error description
            
        Returns:
            True if sent successfully, False otherwise
        """
        try:
            # Read the original message
            messages = self._redis_client.execute_command(
                'XRANGE', self.config.queue.stream_name,
                message_id, message_id
            )
            
            if not messages:
                logger.warning(f"Message {message_id} not found for DLQ")
                return False
            
            # Extract message data
            original_data = messages[0][1]
            json_str = original_data[b'data'] if isinstance(original_data, dict) else original_data['data']
            if isinstance(json_str, bytes):
                json_str = json_str.decode('utf-8')
            
            # Add error information
            dlq_data = {
                'original_message': json_str,
                'error': error,
                'original_message_id': message_id,
                'timestamp': time.time()
            }
            
            # Send to dead letter queue
            import json
            dlq_json = json.dumps(dlq_data)
            dlq_id = self._redis_client.execute_command(
                'XADD', self.config.queue.dead_letter_stream,
                '*', 'data', dlq_json
            )
            
            # Acknowledge original message
            self.acknowledge_message(message_id)
            
            # Update metrics
            self._metrics.record_dead_lettered()
            
            logger.info(f"Sent message {message_id} to DLQ as {dlq_id}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to send message {message_id} to DLQ: {e}")
            return False
    
    def get_queue_depth(self) -> int:
        """
        Get current queue depth (number of pending messages).
        
        Returns:
            Number of pending messages
        """
        try:
            info = self._redis_client.execute_command(
                'XINFO', 'STREAM', self.config.queue.stream_name
            )
            length = info.get('length', 0)
            
            # Update metrics
            self._metrics.record_queue_depth(length)
            
            return length
        except Exception as e:
            logger.error(f"Failed to get queue depth: {e}")
            return 0
    
    def get_pending_count(self) -> int:
        """
        Get number of pending messages for this consumer.
        
        Returns:
            Number of pending messages
        """
        try:
            info = self._redis_client.execute_command(
                'XPENDING', self.config.queue.stream_name,
                self.config.queue.consumer_group
            )
            return info[0]  # First element is pending count
        except Exception as e:
            logger.error(f"Failed to get pending count: {e}")
            return 0
    
    def claim_pending_messages(self, min_idle_time_ms: int = 60000) -> List[ConsumerMessage]:
        """
        Claim pending messages that have been idle too long.
        
        Args:
            min_idle_time_ms: Minimum idle time in milliseconds
            
        Returns:
            List of claimed messages
        """
        try:
            messages = self._redis_client.execute_command(
                'XAUTOCLAIM', self.config.queue.stream_name,
                self.config.queue.consumer_group,
                self.consumer_name,
                str(min_idle_time_ms),
                '0', 'COUNT', str(self.config.queue.batch_size)
            )
            
            if not messages or messages[0] == '0-0':
                return []
            
            claimed = []
            for message_id, fields in messages[1]:
                try:
                    json_str = fields[b'data'] if isinstance(fields, dict) else fields['data']
                    if isinstance(json_str, bytes):
                        json_str = json_str.decode('utf-8')
                    
                    event = self._serializer.deserialize(json_str)
                    claimed.append(
                        ConsumerMessage(message_id=message_id.decode(), event=event)
                    )
                except Exception as e:
                    logger.error(f"Failed to deserialize claimed message {message_id}: {e}")
            
            logger.info(f"Claimed {len(claimed)} pending messages")
            return claimed
            
        except Exception as e:
            logger.error(f"Failed to claim pending messages: {e}")
            return []
    
    def health_check(self) -> dict:
        """
        Perform health check on consumer.
        
        Returns:
            Dict with health status
        """
        health = {
            "status": "healthy",
            "connected": self._is_connected,
            "running": self._is_running,
            "consumer_name": self.consumer_name,
            "queue_depth": 0,
            "pending_count": 0
        }
        
        if self._is_connected and self._redis_client:
            if self._redis_client.ping():
                health["queue_depth"] = self.get_queue_depth()
                health["pending_count"] = self.get_pending_count()
            else:
                health["status"] = "degraded"
        else:
            health["status"] = "unhealthy"
        
        return health
    
    def get_metrics(self):
        """Get current metrics from collector."""
        return self._metrics.get_metrics()
    
    def is_connected(self) -> bool:
        """Check if consumer is connected."""
        return self._is_connected
    
    def __enter__(self):
        """Context manager entry."""
        self.connect()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit."""
        self.disconnect()
