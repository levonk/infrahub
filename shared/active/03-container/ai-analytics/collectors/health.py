"""
Health check endpoints and monitoring for AI analytics collectors.

This module provides health check functionality for collectors, including
status monitoring, performance metrics, and graceful degradation detection.
"""

import time
import asyncio
from typing import Dict, Any, Optional, Callable
from dataclasses import dataclass, field
from enum import Enum
from datetime import datetime, timedelta


class HealthStatus(Enum):
    """Health status of a collector."""
    HEALTHY = "healthy"
    DEGRADED = "degraded"
    UNHEALTHY = "unhealthy"


@dataclass
class HealthCheckResult:
    """Result of a health check."""
    status: HealthStatus
    timestamp: datetime = field(default_factory=datetime.utcnow)
    message: str = ""
    details: Dict[str, Any] = field(default_factory=dict)
    metrics: Dict[str, Any] = field(default_factory=dict)


@dataclass
class PerformanceMetrics:
    """Performance metrics for a collector."""
    total_requests: int = 0
    successful_requests: int = 0
    failed_requests: int = 0
    total_latency_ms: float = 0.0
    min_latency_ms: float = float('inf')
    max_latency_ms: float = 0.0
    last_request_time: Optional[datetime] = None
    
    @property
    def average_latency_ms(self) -> float:
        """Calculate average latency."""
        if self.total_requests == 0:
            return 0.0
        return self.total_latency_ms / self.total_requests
    
    @property
    def success_rate(self) -> float:
        """Calculate success rate."""
        if self.total_requests == 0:
            return 1.0
        return self.successful_requests / self.total_requests
    
    @property
    def error_rate(self) -> float:
        """Calculate error rate."""
        return 1.0 - self.success_rate
    
    def record_request(self, latency_ms: float, success: bool):
        """Record a request with its latency and success status."""
        self.total_requests += 1
        self.total_latency_ms += latency_ms
        self.min_latency_ms = min(self.min_latency_ms, latency_ms)
        self.max_latency_ms = max(self.max_latency_ms, latency_ms)
        self.last_request_time = datetime.utcnow()
        
        if success:
            self.successful_requests += 1
        else:
            self.failed_requests += 1
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert metrics to dictionary."""
        return {
            'total_requests': self.total_requests,
            'successful_requests': self.successful_requests,
            'failed_requests': self.failed_requests,
            'average_latency_ms': self.average_latency_ms,
            'min_latency_ms': self.min_latency_ms if self.min_latency_ms != float('inf') else 0.0,
            'max_latency_ms': self.max_latency_ms,
            'success_rate': self.success_rate,
            'error_rate': self.error_rate,
            'last_request_time': self.last_request_time.isoformat() if self.last_request_time else None
        }


class HealthChecker:
    """
    Health checker for collectors.
    
    Monitors collector health, performance metrics, and detects
    when to enter degraded mode.
    """
    
    def __init__(
        self,
        latency_threshold_ms: float = 5.0,
        error_rate_threshold: float = 0.1,
        stale_request_threshold_seconds: float = 60.0
    ):
        self.latency_threshold_ms = latency_threshold_ms
        self.error_rate_threshold = error_rate_threshold
        self.stale_request_threshold_seconds = stale_request_threshold_seconds
        self.metrics = PerformanceMetrics()
        self._degraded_mode = False
        self._degraded_since: Optional[datetime] = None
        self._health_checks: Dict[str, Callable] = {}
        
    def register_health_check(self, name: str, check: Callable):
        """Register a custom health check function."""
        self._health_checks[name] = check
        
    def record_request(self, latency_ms: float, success: bool):
        """Record a request for metrics tracking."""
        self.metrics.record_request(latency_ms, success)
        
    def check_health(self) -> HealthCheckResult:
        """
        Perform comprehensive health check.
        
        Returns:
            HealthCheckResult with status and details
        """
        issues = []
        warnings = []
        
        # Check latency
        if self.metrics.total_requests > 0:
            avg_latency = self.metrics.average_latency_ms
            if avg_latency > self.latency_threshold_ms:
                issues.append(f"Average latency {avg_latency:.2f}ms exceeds threshold {self.latency_threshold_ms}ms")
        
        # Check error rate
        if self.metrics.total_requests > 10:  # Only check after some requests
            error_rate = self.metrics.error_rate
            if error_rate > self.error_rate_threshold:
                issues.append(f"Error rate {error_rate:.2%} exceeds threshold {self.error_rate_threshold:.2%}")
        
        # Check for stale requests
        if self.metrics.last_request_time:
            time_since_last = (datetime.utcnow() - self.metrics.last_request_time).total_seconds()
            if time_since_last > self.stale_request_threshold_seconds:
                warnings.append(f"No requests for {time_since_last:.0f} seconds")
        
        # Run custom health checks
        for name, check in self._health_checks.items():
            try:
                result = check()
                if not result:
                    issues.append(f"Health check '{name}' failed")
            except Exception as e:
                issues.append(f"Health check '{name}' raised exception: {e}")
        
        # Determine overall status
        if issues:
            status = HealthStatus.UNHEALTHY
            self._set_degraded_mode(True)
        elif warnings:
            status = HealthStatus.DEGRADED
            self._set_degraded_mode(True)
        else:
            status = HealthStatus.HEALTHY
            self._set_degraded_mode(False)
        
        return HealthCheckResult(
            status=status,
            message=self._generate_status_message(status, issues, warnings),
            details={
                'issues': issues,
                'warnings': warnings,
                'degraded_mode': self._degraded_mode,
                'degraded_since': self._degraded_since.isoformat() if self._degraded_since else None
            },
            metrics=self.metrics.to_dict()
        )
    
    def _generate_status_message(
        self, 
        status: HealthStatus, 
        issues: list, 
        warnings: list
    ) -> str:
        """Generate human-readable status message."""
        if status == HealthStatus.HEALTHY:
            return "Collector is operating normally"
        elif status == HealthStatus.DEGRADED:
            return f"Collector is degraded: {', '.join(warnings)}"
        else:
            return f"Collector is unhealthy: {', '.join(issues)}"
    
    def _set_degraded_mode(self, degraded: bool):
        """Set degraded mode state."""
        if degraded and not self._degraded_mode:
            self._degraded_mode = True
            self._degraded_since = datetime.utcnow()
        elif not degraded and self._degraded_mode:
            self._degraded_mode = False
            self._degraded_since = None
    
    def is_degraded(self) -> bool:
        """Check if collector is in degraded mode."""
        return self._degraded_mode
    
    def get_metrics(self) -> Dict[str, Any]:
        """Get current performance metrics."""
        return {
            'metrics': self.metrics.to_dict(),
            'degraded_mode': self._degraded_mode,
            'degraded_since': self._degraded_since.isoformat() if self._degraded_since else None,
            'thresholds': {
                'latency_threshold_ms': self.latency_threshold_ms,
                'error_rate_threshold': self.error_rate_threshold,
                'stale_request_threshold_seconds': self.stale_request_threshold_seconds
            }
        }
    
    def reset_metrics(self):
        """Reset all metrics."""
        self.metrics = PerformanceMetrics()
        self._set_degraded_mode(False)


class HealthCheckServer:
    """
    HTTP server for health check endpoints.
    
    Provides REST endpoints for health checks and metrics.
    """
    
    def __init__(self, host: str = "0.0.0.0", port: int = 8889):
        self.host = host
        self.port = port
        self._health_checker: Optional[HealthChecker] = None
        self._server: Optional[asyncio.Server] = None
        
    def set_health_checker(self, health_checker: HealthChecker):
        """Set the health checker to use."""
        self._health_checker = health_checker
        
    async def start(self):
        """Start the health check server."""
        self._server = await asyncio.start_server(
            self._handle_request,
            self.host,
            self.port
        )
        print(f"Health check server listening on {self.host}:{self.port}")
        
    async def stop(self):
        """Stop the health check server."""
        if self._server:
            self._server.close()
            await self._server.wait_closed()
    
    async def _handle_request(
        self, 
        reader: asyncio.StreamReader, 
        writer: asyncio.StreamWriter
    ):
        """Handle incoming health check requests."""
        try:
            request_line = await reader.readline()
            if not request_line:
                return
            
            method, path, version = request_line.decode().strip().split()
            
            # Read headers
            while True:
                header_line = await reader.readline()
                if header_line == b'\r\n':
                    break
            
            # Route request
            if path == '/health':
                response = self._handle_health_check()
            elif path == '/metrics':
                response = self._handle_metrics()
            elif path == '/health/live':
                response = self._handle_liveness()
            elif path == '/health/ready':
                response = self._handle_readiness()
            else:
                response = self._handle_not_found()
            
            # Send response
            writer.write(response.encode())
            await writer.drain()
            
        except Exception as e:
            writer.write(b'HTTP/1.1 500 Internal Server Error\r\n\r\n')
            await writer.drain()
        finally:
            writer.close()
            await writer.wait_closed()
    
    def _handle_health_check(self) -> str:
        """Handle /health endpoint."""
        if not self._health_checker:
            return self._json_response(500, {'status': 'error', 'message': 'Health checker not configured'})
        
        result = self._health_checker.check_health()
        status_code = 200 if result.status == HealthStatus.HEALTHY else 503
        
        return self._json_response(status_code, {
            'status': result.status.value,
            'message': result.message,
            'details': result.details,
            'metrics': result.metrics
        })
    
    def _handle_metrics(self) -> str:
        """Handle /metrics endpoint."""
        if not self._health_checker:
            return self._json_response(500, {'status': 'error', 'message': 'Health checker not configured'})
        
        return self._json_response(200, self._health_checker.get_metrics())
    
    def _handle_liveness(self) -> str:
        """Handle /health/live endpoint."""
        return self._json_response(200, {'status': 'alive'})
    
    def _handle_readiness(self) -> str:
        """Handle /health/ready endpoint."""
        if not self._health_checker:
            return self._json_response(503, {'status': 'not_ready', 'message': 'Health checker not configured'})
        
        result = self._health_checker.check_health()
        status_code = 200 if result.status == HealthStatus.HEALTHY else 503
        
        return self._json_response(status_code, {
            'status': 'ready' if result.status == HealthStatus.HEALTHY else 'not_ready',
            'health_status': result.status.value
        })
    
    def _handle_not_found(self) -> str:
        """Handle 404 responses."""
        return self._json_response(404, {'status': 'error', 'message': 'Not found'})
    
    def _json_response(self, status_code: int, data: Dict[str, Any]) -> str:
        """Create JSON HTTP response."""
        import json
        body = json.dumps(data)
        return f'HTTP/1.1 {status_code}\r\nContent-Type: application/json\r\nContent-Length: {len(body)}\r\n\r\n{body}'
