"""
Background processor worker for AI analytics pipeline.

This module implements individual workers that process analytics events
from the queue, persist them to the database, and handle errors with retry logic.
"""

import logging
import time
import threading
from typing import Optional, Callable
from dataclasses import dataclass

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'queue'))

from consumer import ConsumerMessage, QueueConsumer
from config import QueueSystemConfig
from metrics import QueueMetricsCollector
from errors import (
    QueueError,
    QueueRetryExhaustedError,
    QueueDeadLetterError
)

from collectors import AnalyticsEvent

logger = logging.getLogger(__name__)


@dataclass
class ProcessingResult:
    """Result of processing a message."""
    success: bool
    message_id: str
    error: Optional[str] = None
    retry_count: int = 0
    processing_time_ms: float = 0.0


class ProcessorWorker:
    """
    Worker that processes analytics events from the queue.
    
    This worker:
    - Deserializes analytics events
    - Persists events to database
    - Handles errors with retry logic
    - Tracks processing time
    - Supports graceful shutdown
    """
    
    def __init__(
        self,
        worker_id: str,
        config: QueueSystemConfig,
        consumer: QueueConsumer,
        metrics: Optional[QueueMetricsCollector] = None,
        process_callback: Optional[Callable] = None
    ):
        """
        Initialize processor worker.
        
        Args:
            worker_id: Unique identifier for this worker
            config: QueueSystemConfig instance
            consumer: QueueConsumer instance for reading messages
            metrics: Optional metrics collector
            process_callback: Optional callback for custom processing logic
        """
        self.worker_id = worker_id
        self.config = config
        self.consumer = consumer
        self._metrics = metrics or QueueMetricsCollector()
        self._process_callback = process_callback
        self._is_running = False
        self._stop_event = threading.Event()
        self._current_message: Optional[ConsumerMessage] = None
        
    def start(self):
        """Start the worker processing loop."""
        self._is_running = True
        self._stop_event.clear()
        logger.info(f"Worker {self.worker_id} started")
        
        while self._is_running and not self._stop_event.is_set():
            try:
                self._process_single_message()
            except Exception as e:
                logger.error(f"Worker {self.worker_id} error in processing loop: {e}")
                time.sleep(1)  # Prevent tight error loop
        
        logger.info(f"Worker {self.worker_id} stopped")
    
    def stop(self, timeout: float = 10.0):
        """
        Stop the worker gracefully.
        
        Args:
            timeout: Maximum time to wait for in-flight message processing
        """
        logger.info(f"Worker {self.worker_id} stopping...")
        self._is_running = False
        self._stop_event.set()
        
        # Wait for current message to finish processing
        start_time = time.time()
        while self._current_message and (time.time() - start_time) < timeout:
            time.sleep(0.1)
        
        if self._current_message:
            logger.warning(f"Worker {self.worker_id} stopped with in-flight message")
    
    def _process_single_message(self):
        """Process a single message from the queue."""
        try:
            # Read message from queue
            messages = self.consumer.read_messages(count=1, block=True)
            
            if not messages:
                return  # No messages available
            
            message = messages[0]
            self._current_message = message
            
            # Update worker status
            self._metrics.record_worker_status(
                self.worker_id, "processing", message.message_id
            )
            
            # Process with retry logic
            result = self._process_with_retry(message)
            
            # Record processing time
            self._metrics.record_processing_time(result.processing_time_ms)
            
            if result.success:
                # Acknowledge successful processing
                self.consumer.acknowledge_message(result.message_id)
                logger.debug(f"Worker {self.worker_id} processed message {result.message_id}")
            else:
                # Handle failure
                self._handle_processing_failure(result)
            
        except Exception as e:
            logger.error(f"Worker {self.worker_id} error processing message: {e}")
            self._metrics.record_failed()
        finally:
            self._current_message = None
            self._metrics.record_worker_status(self.worker_id, "idle")
    
    def _process_with_retry(self, message: ConsumerMessage) -> ProcessingResult:
        """
        Process message with retry logic.
        
        Args:
            message: ConsumerMessage to process
            
        Returns:
            ProcessingResult with outcome
        """
        start_time = time.time()
        last_error = None
        
        for attempt in range(self.config.queue.max_retries + 1):
            try:
                # Process the message
                if self._process_callback:
                    # Use custom callback if provided
                    self._process_callback(message.event)
                else:
                    # Default processing: persist to database
                    self._persist_to_database(message.event)
                
                # Success
                processing_time = (time.time() - start_time) * 1000
                return ProcessingResult(
                    success=True,
                    message_id=message.message_id,
                    retry_count=attempt,
                    processing_time_ms=processing_time
                )
                
            except Exception as e:
                last_error = str(e)
                logger.warning(
                    f"Worker {self.worker_id} attempt {attempt + 1} failed for message {message.message_id}: {e}"
                )
                
                # Record retry
                if attempt < self.config.queue.max_retries:
                    self._metrics.record_retried()
                    # Exponential backoff
                    backoff_time = self.config.queue.retry_backoff_ms * (2 ** attempt) / 1000
                    time.sleep(backoff_time)
        
        # All retries exhausted
        processing_time = (time.time() - start_time) * 1000
        return ProcessingResult(
            success=False,
            message_id=message.message_id,
            error=last_error,
            retry_count=self.config.queue.max_retries,
            processing_time_ms=processing_time
        )
    
    def _persist_to_database(self, event: AnalyticsEvent):
        """
        Persist analytics event to database.
        
        Args:
            event: AnalyticsEvent to persist
            
        Raises:
            Exception: If persistence fails
        """
        # This is a placeholder - actual implementation will use the database
        # schema from Story 01-002 (User-Level Data Model)
        
        # For now, we'll just log the event
        logger.debug(
            f"Persisting event: {event.request_metadata.method} "
            f"{event.request_metadata.path} from {event.request_metadata.client_ip}"
        )
        
        # Simulate database operation
        time.sleep(0.01)  # Simulate database latency
        
        # In real implementation:
        # 1. Extract user attribution from event
        # 2. Insert into appropriate database tables
        # 3. Handle foreign key relationships
        # 4. Use transactions for consistency
    
    def _handle_processing_failure(self, result: ProcessingResult):
        """
        Handle processing failure based on retry count.
        
        Args:
            result: ProcessingResult with failure details
        """
        self._metrics.record_failed()
        
        if result.retry_count >= self.config.queue.max_retries:
            # Max retries exceeded, send to dead letter queue
            logger.error(
                f"Worker {self.worker_id} max retries exceeded for message {result.message_id}, "
                f"sending to DLQ: {result.error}"
            )
            self.consumer.send_to_dead_letter(result.message_id, result.error or "Unknown error")
            raise QueueRetryExhaustedError(
                f"Message {result.message_id} exceeded max retries"
            )
        else:
            # Will be retried in next processing loop
            logger.warning(
                f"Worker {self.worker_id} message {result.message_id} will be retried: {result.error}"
            )
    
    def process_message_sync(self, message: ConsumerMessage) -> ProcessingResult:
        """
        Process a single message synchronously (for testing).
        
        Args:
            message: ConsumerMessage to process
            
        Returns:
            ProcessingResult with outcome
        """
        self._current_message = message
        try:
            result = self._process_with_retry(message)
            self._metrics.record_processing_time(result.processing_time_ms)
            return result
        finally:
            self._current_message = None
    
    def health_check(self) -> dict:
        """
        Perform health check on worker.
        
        Returns:
            Dict with health status
        """
        return {
            "worker_id": self.worker_id,
            "running": self._is_running,
            "current_message": self._current_message.message_id if self._current_message else None,
            "status": "processing" if self._current_message else "idle"
        }
    
    def get_metrics(self):
        """Get current metrics from collector."""
        return self._metrics.get_metrics()
    
    def is_running(self) -> bool:
        """Check if worker is running."""
        return self._is_running
