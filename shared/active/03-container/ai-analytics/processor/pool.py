"""
Worker pool management for AI analytics pipeline.

This module manages a pool of processor workers, providing load balancing,
health monitoring, and graceful shutdown coordination.
"""

import logging
import threading
import time
from typing import List, Optional, Dict, Any
from concurrent.futures import ThreadPoolExecutor

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'queue'))

from worker import ProcessorWorker
from consumer import QueueConsumer
from config import QueueSystemConfig
from metrics import QueueMetricsCollector

logger = logging.getLogger(__name__)


class WorkerPool:
    """
    Pool of processor workers for parallel message processing.
    
    This pool:
    - Manages multiple worker instances
    - Provides load balancing across workers
    - Monitors worker health
    - Coordinates graceful shutdown
    - Tracks worker utilization
    """
    
    def __init__(
        self,
        config: QueueSystemConfig,
        consumer: QueueConsumer,
        metrics: Optional[QueueMetricsCollector] = None
    ):
        """
        Initialize worker pool.
        
        Args:
            config: QueueSystemConfig instance
            consumer: QueueConsumer instance for workers
            metrics: Optional metrics collector
        """
        self.config = config
        self.consumer = consumer
        self._metrics = metrics or QueueMetricsCollector()
        self._workers: List[ProcessorWorker] = []
        self._executor: Optional[ThreadPoolExecutor] = None
        self._is_running = False
        self._lock = threading.Lock()
        
    def start(self):
        """Start the worker pool with configured number of workers."""
        with self._lock:
            if self._is_running:
                logger.warning("Worker pool already running")
                return
            
            self._executor = ThreadPoolExecutor(
                max_workers=self.config.processor.worker_count,
                thread_name_prefix="analytics-worker"
            )
            
            # Create and start workers
            for i in range(self.config.processor.worker_count):
                worker_id = f"worker-{i}"
                worker = ProcessorWorker(
                    worker_id=worker_id,
                    config=self.config,
                    consumer=self.consumer,
                    metrics=self._metrics
                )
                self._workers.append(worker)
                
                # Submit worker to thread pool
                self._executor.submit(worker.start)
            
            self._is_running = True
            logger.info(f"Worker pool started with {len(self._workers)} workers")
    
    def stop(self, timeout: float = 10.0):
        """
        Stop all workers gracefully.
        
        Args:
            timeout: Maximum time to wait for workers to stop
        """
        with self._lock:
            if not self._is_running:
                logger.warning("Worker pool not running")
                return
            
            logger.info("Stopping worker pool...")
            self._is_running = False
            
            # Stop all workers
            for worker in self._workers:
                worker.stop(timeout=timeout)
            
            # Shutdown executor
            if self._executor:
                self._executor.shutdown(wait=True, timeout=timeout)
                self._executor = None
            
            self._workers.clear()
            logger.info("Worker pool stopped")
    
    def scale(self, new_worker_count: int):
        """
        Scale the worker pool to a new size.
        
        Args:
            new_worker_count: New number of workers
        """
        with self._lock:
            if not self._is_running:
                logger.warning("Cannot scale: worker pool not running")
                return
            
            current_count = len(self._workers)
            
            if new_worker_count == current_count:
                logger.info(f"Worker pool already at {new_worker_count} workers")
                return
            
            if new_worker_count < current_count:
                # Scale down
                workers_to_remove = current_count - new_worker_count
                logger.info(f"Scaling down: removing {workers_to_remove} workers")
                
                for i in range(workers_to_remove):
                    worker = self._workers.pop()
                    worker.stop()
                    
            elif new_worker_count > current_count:
                # Scale up
                workers_to_add = new_worker_count - current_count
                logger.info(f"Scaling up: adding {workers_to_add} workers")
                
                for i in range(workers_to_add):
                    worker_id = f"worker-{current_count + i}"
                    worker = ProcessorWorker(
                        worker_id=worker_id,
                        config=self.config,
                        consumer=self.consumer,
                        metrics=self._metrics
                    )
                    self._workers.append(worker)
                    
                    # Submit worker to thread pool
                    if self._executor:
                        self._executor.submit(worker.start)
            
            self.config.processor.worker_count = new_worker_count
            logger.info(f"Worker pool scaled to {len(self._workers)} workers")
    
    def get_worker_count(self) -> int:
        """Get current number of workers."""
        with self._lock:
            return len(self._workers)
    
    def get_worker_status(self) -> List[Dict[str, Any]]:
        """
        Get status of all workers.
        
        Returns:
            List of worker status dictionaries
        """
        with self._lock:
            return [worker.health_check() for worker in self._workers]
    
    def get_active_worker_count(self) -> int:
        """
        Get number of currently active (processing) workers.
        
        Returns:
            Number of active workers
        """
        with self._lock:
            return sum(
                1 for worker in self._workers
                if worker.is_running() and worker._current_message is not None
            )
    
    def health_check(self) -> Dict[str, Any]:
        """
        Perform health check on worker pool.
        
        Returns:
            Dict with health status
        """
        with self._lock:
            worker_statuses = self.get_worker_status()
            active_count = self.get_active_worker_count()
            
            health = {
                "status": "healthy",
                "running": self._is_running,
                "total_workers": len(self._workers),
                "active_workers": active_count,
                "idle_workers": len(self._workers) - active_count,
                "worker_utilization": active_count / len(self._workers) if self._workers else 0.0,
                "workers": worker_statuses
            }
            
            # Check for unhealthy workers
            unhealthy_workers = [
                w for w in worker_statuses
                if not w.get("running", False)
            ]
            
            if unhealthy_workers:
                health["status"] = "degraded"
                health["unhealthy_workers"] = len(unhealthy_workers)
            
            return health
    
    def get_metrics(self):
        """Get current metrics from collector."""
        return self._metrics.get_metrics()
    
    def is_running(self) -> bool:
        """Check if worker pool is running."""
        with self._lock:
            return self._is_running
    
    def __enter__(self):
        """Context manager entry."""
        self.start()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit."""
        self.stop()
