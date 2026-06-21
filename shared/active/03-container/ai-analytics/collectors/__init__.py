"""
AI Analytics Collectors Package

This package provides collector components for intercepting and capturing
AI requests with minimal latency impact.
"""

from .base import (
    BaseCollector,
    RequestMetadata,
    ResponseMetadata,
    AnalyticsEvent,
    CollectorPosition,
    CollectorError,
    CollectorDegradedError,
    compute_content_hash,
    sanitize_headers,
    extract_client_ip
)

from .proxy import (
    HTTPProxyCollector,
    ProxyConfig
)

from .middleware import (
    RequestInterceptor,
    ResponseInterceptor,
    MiddlewareChain,
    ContentSanitizer,
    MiddlewareConfig
)

from .hashing import (
    compute_content_hash,
    compute_request_hash,
    compute_response_hash,
    compute_correlation_id,
    HashCache
)

from .config import (
    CollectorConfig,
    ProxyCollectorConfig,
    ConfigManager,
    create_default_config_file
)

from .health import (
    HealthStatus,
    HealthCheckResult,
    PerformanceMetrics,
    HealthChecker,
    HealthCheckServer
)

from .errors import (
    ErrorSeverity,
    ErrorCategory,
    ErrorContext,
    CollectorError,
    NetworkError,
    TimeoutError,
    ValidationError,
    ResourceError,
    DegradedModeError,
    ErrorHandler,
    GracefulDegradationManager,
    handle_errors
)

from .monitoring import (
    PerformanceSnapshot,
    LatencySample,
    PerformanceMonitor,
    LatencyThresholdAlert,
    ErrorRateAlert,
    ResourceAlert,
    AlertManager
)

__version__ = "0.1.0"
__all__ = [
    # Base
    'BaseCollector',
    'RequestMetadata',
    'ResponseMetadata',
    'AnalyticsEvent',
    'CollectorPosition',
    'CollectorError',
    'CollectorDegradedError',
    'compute_content_hash',
    'sanitize_headers',
    'extract_client_ip',
    
    # Proxy
    'HTTPProxyCollector',
    'ProxyConfig',
    
    # Middleware
    'RequestInterceptor',
    'ResponseInterceptor',
    'MiddlewareChain',
    'ContentSanitizer',
    'MiddlewareConfig',
    
    # Hashing
    'compute_content_hash',
    'compute_request_hash',
    'compute_response_hash',
    'compute_correlation_id',
    'HashCache',
    
    # Config
    'CollectorConfig',
    'ProxyCollectorConfig',
    'ConfigManager',
    'create_default_config_file',
    
    # Health
    'HealthStatus',
    'HealthCheckResult',
    'PerformanceMetrics',
    'HealthChecker',
    'HealthCheckServer',
    
    # Errors
    'ErrorSeverity',
    'ErrorCategory',
    'ErrorContext',
    'CollectorError',
    'NetworkError',
    'TimeoutError',
    'ValidationError',
    'ResourceError',
    'DegradedModeError',
    'ErrorHandler',
    'GracefulDegradationManager',
    'handle_errors',
    
    # Monitoring
    'PerformanceSnapshot',
    'LatencySample',
    'PerformanceMonitor',
    'LatencyThresholdAlert',
    'ErrorRateAlert',
    'ResourceAlert',
    'AlertManager'
]
