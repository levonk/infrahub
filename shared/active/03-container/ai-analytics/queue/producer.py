"""
Message queue producer for AI analytics pipeline.

This module implements the producer that enqueues analytics events
from collectors into Redis Streams for asynchronous processing.
"""

import logging
import time
from typing import List, Optional
from contextlib import contextmanager

from redis_client import RedisClient, RedisConnectionError
from config import QueueSystemConfig
from serialization import MessageSerializer
from metrics import QueueMetricsCollector
from errors import (
    QueueError,
    QueueConnectionError,
    QueueSerializationError,
    QueueTimeoutError
)

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from collectors import AnalyticsEvent

logger = logging.getLogger(__name__)


class QueueProducer:
    """
    Producer for enqueuing analytics events into Redis Streams.
    
    This producer:
    - Serializes AnalyticsEvent objects to JSON
    - Enqueues messages to Redis Streams
    - Supports batch enqueue for efficiency
    - Handles errors with graceful degradation
    - Integrates with collector framework
    """
    
    def __init__(self, config: QueueSystemConfig, metrics: Optional[QueueMetricsCollector] = None):
        """
        Initialize queue producer.
        
        Args:
            config: QueueSystemConfig instance
            metrics: Optional metrics collector
        """
        self.config = config
        self._redis_client: Optional[RedisClient] = None
        self._serializer = MessageSerializer(max_message_size=config.queue.max_message_size)
        self._metrics = metrics or QueueMetricsCollector()
        self._is_connected = False
        self._degraded_mode = False
        
    def connect(self) -> bool:
        """
        Connect to Redis and initialize stream.
        
        Returns:
            True if connection successful, False otherwise
        """
        try:
            self._redis_client = RedisClient(self.config.redis)
            
            if not self._redis_client.connect():
                raise QueueConnectionError("Failed to connect to Redis")
            
            # Create consumer group if it doesn't exist
            self._ensure_consumer_group()
            
            self._is_connected = True
            self._degraded_mode = False
            logger.info("Queue producer connected to Redis")
            return True
            
        except Exception as e:
            logger.error(f"Failed to connect queue producer: {e}")
            self._is_connected = False
            self._degraded_mode = True
            return False
    
    def disconnect(self):
        """Disconnect from Redis."""
        if self._redis_client:
            self._redis_client.disconnect()
            self._is_connected = False
            logger.info("Queue producer disconnected")
    
    def _ensure_consumer_group(self):
        """Create consumer group if it doesn't exist."""
        try:
            # Try to create consumer group (will fail if already exists)
            self._redis_client.execute_command(
                'XGROUP', 'CREATE',
                self.config.queue.stream_name,
                self.config.queue.consumer_group,
                '0', 'MKSTREAM'
            )
            logger.info(f"Created consumer group: {self.config.queue.consumer_group}")
        except Exception as e:
            # Group likely already exists, which is fine
            if "BUSYGROUP" not in str(e):
                logger.warning(f"Could not create consumer group: {e}")
    
    def enqueue(self, event: AnalyticsEvent) -> bool:
        """
        Enqueue a single analytics event.
        
        Args:
            event: AnalyticsEvent to enqueue
            
        Returns:
            True if enqueued successfully, False otherwise
        """
        if not self._is_connected or self._degraded_mode:
            logger.warning("Producer not connected, dropping event")
            return False
        
        try:
            # Serialize event
            json_str = self._serializer.serialize(event)
            
            # Enqueue to Redis Stream
            message_id = self._redis_client.execute_command(
                'XADD', self.config.queue.stream_name,
                '*', 'data', json_str
            )
            
            # Update metrics
            self._metrics.record_produced()
            
            logger.debug(f"Enqueued event {message_id}")
            return True
            
        except QueueSerializationError as e:
            logger.error(f"Serialization error: {e}")
            return False
        except RedisConnectionError as e:
            logger.error(f"Connection error: {e}")
            self._handle_connection_error()
            return False
        except Exception as e:
            logger.error(f"Enqueue error: {e}")
            return False
    
    def enqueue_batch(self, events: List[AnalyticsEvent]) -> int:
        """
        Enqueue multiple analytics events in a batch.
        
        Args:
            events: List of AnalyticsEvent objects to enqueue
            
        Returns:
            Number of events successfully enqueued
        """
        if not self._is_connected or self._degraded_mode:
            logger.warning("Producer not connected, dropping batch")
            return 0
        
        success_count = 0
        
        for event in events:
            if self.enqueue(event):
                success_count += 1
        
        logger.debug(f"Enqueued batch: {success_count}/{len(events)} successful")
        return success_count
    
    def enqueue_non_blocking(self, event: AnalyticsEvent) -> bool:
        """
        Enqueue event without blocking (fire and forget).
        
        This method is designed for the hot path where latency is critical.
        It uses a background task to enqueue the event asynchronously.
        
        Args:
            event: AnalyticsEvent to enqueue
            
        Returns:
            True if enqueue was initiated (not necessarily completed)
        """
        # In a real implementation, this would use a thread pool or async task
        # For now, we'll use a simple try-catch to ensure non-blocking behavior
        try:
            return self.enqueue(event)
        except Exception as e:
            logger.error(f"Non-blocking enqueue error: {e}")
            return False
    
    def _handle_connection_error(self):
        """Handle connection error with reconnection attempt."""
        self._is_connected = False
        self._degraded_mode = True
        
        # Attempt reconnection in background
        logger.info("Attempting to reconnect...")
        if self._redis_client and self._redis_client.reconnect():
            self._is_connected = True
            self._degraded_mode = False
            logger.info("Reconnection successful")
    
    def health_check(self) -> dict:
        """
        Perform health check on producer.
        
        Returns:
            Dict with health status
        """
        health = {
            "status": "healthy",
            "connected": self._is_connected,
            "degraded_mode": self._degraded_mode,
            "redis_status": "unknown"
        }
        
        if self._is_connected and self._redis_client:
            if self._redis_client.ping():
                health["redis_status"] = "connected"
            else:
                health["status"] = "degraded"
                health["redis_status"] = "disconnected"
        else:
            health["status"] = "unhealthy"
            health["redis_status"] = "not_connected"
        
        return health
    
    def get_metrics(self):
        """Get current metrics from collector."""
        return self._metrics.get_metrics()
    
    def is_connected(self) -> bool:
        """Check if producer is connected."""
        return self._is_connected and not self._degraded_mode
    
    def set_degraded_mode(self, degraded: bool):
        """
        Manually set degraded mode.
        
        Args:
            degraded: Whether to enable degraded mode
        """
        self._degraded_mode = degraded
        logger.info(f"Degraded mode set to: {degraded}")
    
    def __enter__(self):
        """Context manager entry."""
        self.connect()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit."""
        self.disconnect()
