"""
Queue monitoring and metrics for AI analytics pipeline.

This module provides metrics collection for the message queue system,
including queue depth, processing rates, error rates, and worker utilization.
"""

import time
from threading import Lock
from collections import defaultdict
from typing import Dict, Any
from dataclasses import dataclass, field


@dataclass
class QueueMetrics:
    """Metrics for queue operations."""
    messages_produced: int = 0
    messages_consumed: int = 0
    messages_failed: int = 0
    messages_retried: int = 0
    messages_dead_lettered: int = 0
    queue_depth: int = 0
    processing_rate_per_second: float = 0.0
    error_rate: float = 0.0
    avg_processing_time_ms: float = 0.0
    worker_utilization: float = 0.0
    last_updated: float = field(default_factory=time.time)


class QueueMetricsCollector:
    """
    Collector for queue metrics with thread-safe operations.
    
    This collector tracks:
    - Message throughput (produced/consumed)
    - Error rates and retry counts
    - Queue depth over time
    - Processing latency
    - Worker pool utilization
    """
    
    def __init__(self):
        self._lock = Lock()
        self._metrics = QueueMetrics()
        self._processing_times = []
        self._start_time = time.time()
        self._worker_status = defaultdict(dict)
    
    def record_produced(self, count: int = 1):
        """Record message production."""
        with self._lock:
            self._metrics.messages_produced += count
            self._metrics.last_updated = time.time()
    
    def record_consumed(self, count: int = 1):
        """Record message consumption."""
        with self._lock:
            self._metrics.messages_consumed += count
            self._metrics.last_updated = time.time()
    
    def record_failed(self, count: int = 1):
        """Record message processing failure."""
        with self._lock:
            self._metrics.messages_failed += count
            self._metrics.last_updated = time.time()
    
    def record_retried(self, count: int = 1):
        """Record message retry."""
        with self._lock:
            self._metrics.messages_retried += count
            self._metrics.last_updated = time.time()
    
    def record_dead_lettered(self, count: int = 1):
        """Record message sent to dead letter queue."""
        with self._lock:
            self._metrics.messages_dead_lettered += count
            self._metrics.last_updated = time.time()
    
    def record_queue_depth(self, depth: int):
        """Record current queue depth."""
        with self._lock:
            self._metrics.queue_depth = depth
            self._metrics.last_updated = time.time()
    
    def record_processing_time(self, duration_ms: float):
        """Record processing time for a message."""
        with self._lock:
            self._processing_times.append(duration_ms)
            # Keep only last 1000 measurements
            if len(self._processing_times) > 1000:
                self._processing_times = self._processing_times[-1000:]
            
            # Update average
            if self._processing_times:
                self._metrics.avg_processing_time_ms = sum(self._processing_times) / len(self._processing_times)
            
            self._metrics.last_updated = time.time()
    
    def record_worker_status(self, worker_id: str, status: str, current_task: str = None):
        """Record worker status for utilization tracking."""
        with self._lock:
            self._worker_status[worker_id] = {
                "status": status,
                "current_task": current_task,
                "last_updated": time.time()
            }
            self._metrics.last_updated = time.time()
    
    def get_metrics(self) -> QueueMetrics:
        """
        Get current metrics snapshot.
        
        Returns:
            QueueMetrics with current values
        """
        with self._lock:
            # Calculate derived metrics
            elapsed_time = time.time() - self._start_time
            
            if elapsed_time > 0:
                self._metrics.processing_rate_per_second = (
                    self._metrics.messages_consumed / elapsed_time
                )
            
            total_messages = self._metrics.messages_consumed + self._metrics.messages_failed
            if total_messages > 0:
                self._metrics.error_rate = self._metrics.messages_failed / total_messages
            
            # Calculate worker utilization
            active_workers = sum(
                1 for status in self._worker_status.values()
                if status.get("status") == "processing"
            )
            total_workers = len(self._worker_status)
            if total_workers > 0:
                self._metrics.worker_utilization = active_workers / total_workers
            
            # Return a copy to avoid external modification
            return QueueMetrics(
                messages_produced=self._metrics.messages_produced,
                messages_consumed=self._metrics.messages_consumed,
                messages_failed=self._metrics.messages_failed,
                messages_retried=self._metrics.messages_retried,
                messages_dead_lettered=self._metrics.messages_dead_lettered,
                queue_depth=self._metrics.queue_depth,
                processing_rate_per_second=self._metrics.processing_rate_per_second,
                error_rate=self._metrics.error_rate,
                avg_processing_time_ms=self._metrics.avg_processing_time_ms,
                worker_utilization=self._metrics.worker_utilization,
                last_updated=self._metrics.last_updated
            )
    
    def get_health_status(self) -> Dict[str, Any]:
        """
        Get health status based on metrics.
        
        Returns:
            Dict with health indicators
        """
        metrics = self.get_metrics()
        
        health_status = {
            "status": "healthy",
            "indicators": {},
            "warnings": [],
            "errors": []
        }
        
        # Check queue depth
        if metrics.queue_depth > 5000:
            health_status["status"] = "critical"
            health_status["errors"].append(f"Queue depth critical: {metrics.queue_depth}")
        elif metrics.queue_depth > 1000:
            health_status["status"] = "warning"
            health_status["warnings"].append(f"Queue depth elevated: {metrics.queue_depth}")
        
        # Check error rate
        if metrics.error_rate > 0.1:  # 10% error rate
            health_status["status"] = "critical"
            health_status["errors"].append(f"Error rate critical: {metrics.error_rate:.2%}")
        elif metrics.error_rate > 0.05:  # 5% error rate
            health_status["status"] = "warning"
            health_status["warnings"].append(f"Error rate elevated: {metrics.error_rate:.2%}")
        
        # Check worker utilization
        if metrics.worker_utilization > 0.9:
            health_status["warnings"].append(f"Worker utilization high: {metrics.worker_utilization:.2%}")
        
        # Check processing rate
        if metrics.processing_rate_per_second < 1.0 and metrics.queue_depth > 100:
            health_status["warnings"].append("Processing rate low with backlog")
        
        health_status["indicators"] = {
            "queue_depth": metrics.queue_depth,
            "error_rate": f"{metrics.error_rate:.2%}",
            "processing_rate": f"{metrics.processing_rate_per_second:.2f} msg/s",
            "worker_utilization": f"{metrics.worker_utilization:.2%}",
            "avg_processing_time": f"{metrics.avg_processing_time_ms:.2f}ms"
        }
        
        return health_status
    
    def reset(self):
        """Reset all metrics to zero."""
        with self._lock:
            self._metrics = QueueMetrics()
            self._processing_times = []
            self._start_time = time.time()
            self._worker_status.clear()
