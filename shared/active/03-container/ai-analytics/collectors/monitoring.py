"""
Performance monitoring for AI analytics collectors.

This module provides comprehensive performance monitoring including
latency tracking, throughput measurement, and resource utilization.
"""

import time
import asyncio
import psutil
from typing import Dict, Any, Optional, List, Callable
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from collections import deque
from threading import Lock
import statistics


@dataclass
class PerformanceSnapshot:
    """Snapshot of performance metrics at a point in time."""
    timestamp: datetime = field(default_factory=datetime.utcnow)
    cpu_percent: float = 0.0
    memory_percent: float = 0.0
    memory_mb: float = 0.0
    request_count: int = 0
    error_count: int = 0
    avg_latency_ms: float = 0.0
    p50_latency_ms: float = 0.0
    p95_latency_ms: float = 0.0
    p99_latency_ms: float = 0.0
    throughput_rps: float = 0.0


@dataclass
class LatencySample:
    """Individual latency sample."""
    timestamp: datetime
    latency_ms: float
    success: bool


class PerformanceMonitor:
    """
    Performance monitor for collectors.
    
    Tracks latency, throughput, error rates, and resource utilization
    with configurable time windows and aggregation.
    """
    
    def __init__(
        self,
        window_size_seconds: float = 60.0,
        sample_interval_seconds: float = 1.0,
        max_samples: int = 10000
    ):
        self.window_size_seconds = window_size_seconds
        self.sample_interval_seconds = sample_interval_seconds
        self.max_samples = max_samples
        
        self._latency_samples: deque = deque(maxlen=max_samples)
        self._request_count = 0
        self._error_count = 0
        self._start_time = datetime.utcnow()
        
        self._lock = Lock()
        self._monitoring_task: Optional[asyncio.Task] = None
        self._callbacks: List[Callable] = []
        
    def start_monitoring(self):
        """Start background monitoring task."""
        if self._monitoring_task is None or self._monitoring_task.done():
            self._monitoring_task = asyncio.create_task(self._monitoring_loop())
    
    async def stop_monitoring(self):
        """Stop background monitoring task."""
        if self._monitoring_task:
            self._monitoring_task.cancel()
            try:
                await self._monitoring_task
            except asyncio.CancelledError:
                pass
    
    async def _monitoring_loop(self):
        """Background monitoring loop."""
        while True:
            try:
                await asyncio.sleep(self.sample_interval_seconds)
                snapshot = self.get_snapshot()
                
                # Call registered callbacks
                for callback in self._callbacks:
                    try:
                        callback(snapshot)
                    except Exception as e:
                        print(f"Performance callback error: {e}")
                        
            except asyncio.CancelledError:
                break
            except Exception as e:
                print(f"Monitoring loop error: {e}")
    
    def register_callback(self, callback: Callable):
        """Register a callback for performance snapshots."""
        self._callbacks.append(callback)
    
    def record_request(self, latency_ms: float, success: bool = True):
        """
        Record a request with its latency and success status.
        
        Args:
            latency_ms: Request latency in milliseconds
            success: Whether the request was successful
        """
        with self._lock:
            self._latency_samples.append(LatencySample(
                timestamp=datetime.utcnow(),
                latency_ms=latency_ms,
                success=success
            ))
            self._request_count += 1
            if not success:
                self._error_count += 1
    
    def get_snapshot(self) -> PerformanceSnapshot:
        """Get current performance snapshot."""
        with self._lock:
            # Filter samples within time window
            cutoff_time = datetime.utcnow() - timedelta(seconds=self.window_size_seconds)
            recent_samples = [
                sample for sample in self._latency_samples
                if sample.timestamp > cutoff_time
            ]
            
            # Calculate latency percentiles
            latencies = [sample.latency_ms for sample in recent_samples]
            if latencies:
                avg_latency = statistics.mean(latencies)
                p50_latency = statistics.median(latencies)
                sorted_latencies = sorted(latencies)
                p95_latency = sorted_latencies[int(len(sorted_latencies) * 0.95)] if sorted_latencies else 0
                p99_latency = sorted_latencies[int(len(sorted_latencies) * 0.99)] if sorted_latencies else 0
            else:
                avg_latency = 0.0
                p50_latency = 0.0
                p95_latency = 0.0
                p99_latency = 0.0
            
            # Calculate throughput
            if recent_samples:
                time_span = (recent_samples[-1].timestamp - recent_samples[0].timestamp).total_seconds()
                throughput = len(recent_samples) / time_span if time_span > 0 else 0
            else:
                throughput = 0.0
            
            # Get resource utilization
            process = psutil.Process()
            cpu_percent = process.cpu_percent()
            memory_info = process.memory_info()
            memory_percent = process.memory_percent()
            memory_mb = memory_info.rss / (1024 * 1024)
            
            return PerformanceSnapshot(
                cpu_percent=cpu_percent,
                memory_percent=memory_percent,
                memory_mb=memory_mb,
                request_count=self._request_count,
                error_count=self._error_count,
                avg_latency_ms=avg_latency,
                p50_latency_ms=p50_latency,
                p95_latency_ms=p95_latency,
                p99_latency_ms=p99_latency,
                throughput_rps=throughput
            )
    
    def get_metrics(self) -> Dict[str, Any]:
        """Get comprehensive performance metrics."""
        snapshot = self.get_snapshot()
        
        uptime = (datetime.utcnow() - self._start_time).total_seconds()
        error_rate = self._error_count / self._request_count if self._request_count > 0 else 0
        
        return {
            'uptime_seconds': uptime,
            'total_requests': self._request_count,
            'total_errors': self._error_count,
            'error_rate': error_rate,
            'latency': {
                'average_ms': snapshot.avg_latency_ms,
                'p50_ms': snapshot.p50_latency_ms,
                'p95_ms': snapshot.p95_latency_ms,
                'p99_ms': snapshot.p99_latency_ms
            },
            'throughput': {
                'requests_per_second': snapshot.throughput_rps
            },
            'resources': {
                'cpu_percent': snapshot.cpu_percent,
                'memory_percent': snapshot.memory_percent,
                'memory_mb': snapshot.memory_mb
            },
            'window': {
                'size_seconds': self.window_size_seconds,
                'sample_count': len(self._latency_samples)
            }
        }
    
    def get_latency_history(self, limit: int = 100) -> List[Dict[str, Any]]:
        """Get recent latency samples."""
        with self._lock:
            samples = list(self._latency_samples)[-limit:]
            return [
                {
                    'timestamp': sample.timestamp.isoformat(),
                    'latency_ms': sample.latency_ms,
                    'success': sample.success
                }
                for sample in samples
            ]
    
    def reset_metrics(self):
        """Reset all metrics."""
        with self._lock:
            self._latency_samples.clear()
            self._request_count = 0
            self._error_count = 0
            self._start_time = datetime.utcnow()


class LatencyThresholdAlert:
    """Alert when latency exceeds threshold."""
    
    def __init__(self, threshold_ms: float, callback: Callable):
        self.threshold_ms = threshold_ms
        self.callback = callback
        self._triggered_count = 0
    
    def check(self, snapshot: PerformanceSnapshot):
        """Check if threshold is exceeded."""
        if snapshot.p95_latency_ms > self.threshold_ms:
            self._triggered_count += 1
            self.callback({
                'type': 'latency_threshold',
                'threshold_ms': self.threshold_ms,
                'actual_ms': snapshot.p95_latency_ms,
                'triggered_count': self._triggered_count
            })


class ErrorRateAlert:
    """Alert when error rate exceeds threshold."""
    
    def __init__(self, threshold_rate: float, callback: Callable):
        self.threshold_rate = threshold_rate
        self.callback = callback
        self._triggered_count = 0
    
    def check(self, snapshot: PerformanceSnapshot):
        """Check if error rate threshold is exceeded."""
        error_rate = snapshot.error_count / snapshot.request_count if snapshot.request_count > 0 else 0
        if error_rate > self.threshold_rate:
            self._triggered_count += 1
            self.callback({
                'type': 'error_rate',
                'threshold_rate': self.threshold_rate,
                'actual_rate': error_rate,
                'triggered_count': self._triggered_count
            })


class ResourceAlert:
    """Alert when resource utilization exceeds threshold."""
    
    def __init__(self, resource_type: str, threshold_percent: float, callback: Callable):
        self.resource_type = resource_type
        self.threshold_percent = threshold_percent
        self.callback = callback
        self._triggered_count = 0
    
    def check(self, snapshot: PerformanceSnapshot):
        """Check if resource threshold is exceeded."""
        if self.resource_type == 'cpu':
            actual = snapshot.cpu_percent
        elif self.resource_type == 'memory':
            actual = snapshot.memory_percent
        else:
            return
        
        if actual > self.threshold_percent:
            self._triggered_count += 1
            self.callback({
                'type': 'resource',
                'resource_type': self.resource_type,
                'threshold_percent': self.threshold_percent,
                'actual_percent': actual,
                'triggered_count': self._triggered_count
            })


class AlertManager:
    """Manages performance alerts and notifications."""
    
    def __init__(self, performance_monitor: PerformanceMonitor):
        self.performance_monitor = performance_monitor
        self._alerts: List = []
        
    def add_latency_alert(self, threshold_ms: float, callback: Callable):
        """Add latency threshold alert."""
        alert = LatencyThresholdAlert(threshold_ms, callback)
        self._alerts.append(alert)
        
    def add_error_rate_alert(self, threshold_rate: float, callback: Callable):
        """Add error rate alert."""
        alert = ErrorRateAlert(threshold_rate, callback)
        self._alerts.append(alert)
        
    def add_resource_alert(self, resource_type: str, threshold_percent: float, callback: Callable):
        """Add resource utilization alert."""
        alert = ResourceAlert(resource_type, threshold_percent, callback)
        self._alerts.append(alert)
    
    def check_alerts(self):
        """Check all registered alerts."""
        snapshot = self.performance_monitor.get_snapshot()
        for alert in self._alerts:
            alert.check(snapshot)
    
    def start_monitoring(self):
        """Start alert monitoring."""
        def alert_callback(snapshot):
            self.check_alerts()
        
        self.performance_monitor.register_callback(alert_callback)
        self.performance_monitor.start_monitoring()
    
    async def stop_monitoring(self):
        """Stop alert monitoring."""
        await self.performance_monitor.stop_monitoring()
