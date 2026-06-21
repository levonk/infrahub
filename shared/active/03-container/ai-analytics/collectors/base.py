"""
Base collector interface and utilities for AI analytics pipeline.

This module defines the abstract interface that all collectors must implement,
providing a consistent contract for request interception, metadata extraction,
and analytics queuing.
"""

from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Dict, Any, Optional, Callable
from enum import Enum
import time
import hashlib


class CollectorPosition(Enum):
    """Position of the collector in the request pipeline."""
    PRE_PROCESSING = "pre_processing"
    POST_PROCESSING = "post_processing"


@dataclass
class RequestMetadata:
    """Metadata extracted from incoming requests."""
    method: str
    path: str
    headers: Dict[str, str]
    query_params: Dict[str, str]
    client_ip: str
    timestamp: float = field(default_factory=time.time)
    content_hash: Optional[str] = None
    content_size: int = 0


@dataclass
class ResponseMetadata:
    """Metadata extracted from responses."""
    status_code: int
    headers: Dict[str, str]
    timestamp: float = field(default_factory=time.time)
    content_size: int = 0
    duration_ms: float = 0.0


@dataclass
class AnalyticsEvent:
    """Complete analytics event for queuing."""
    request_metadata: RequestMetadata
    response_metadata: Optional[ResponseMetadata] = None
    position: CollectorPosition = CollectorPosition.PRE_PROCESSING
    additional_data: Dict[str, Any] = field(default_factory=dict)


class CollectorError(Exception):
    """Base exception for collector errors."""
    pass


class CollectorDegradedError(CollectorError):
    """Raised when collector is in degraded mode but still operational."""
    pass


class BaseCollector(ABC):
    """
    Abstract base class for all collectors.
    
    Collectors must implement request interception, metadata extraction,
    and analytics queuing while maintaining minimal latency impact.
    """
    
    def __init__(self, position: CollectorPosition = CollectorPosition.PRE_PROCESSING):
        self.position = position
        self._error_handler: Optional[Callable] = None
        self._degraded_mode = False
    
    @abstractmethod
    def intercept_request(self, request: Any) -> RequestMetadata:
        """
        Intercept and extract metadata from incoming request.
        
        Args:
            request: The incoming request object (framework-specific)
            
        Returns:
            RequestMetadata with extracted information
            
        Raises:
            CollectorError: If request interception fails critically
        """
        pass
    
    @abstractmethod
    def intercept_response(self, response: Any, request_metadata: RequestMetadata) -> ResponseMetadata:
        """
        Intercept and extract metadata from outgoing response.
        
        Args:
            response: The outgoing response object (framework-specific)
            request_metadata: Original request metadata for correlation
            
        Returns:
            ResponseMetadata with extracted information
        """
        pass
    
    @abstractmethod
    def queue_analytics(self, event: AnalyticsEvent) -> bool:
        """
        Queue analytics event for async processing.
        
        Args:
            event: The analytics event to queue
            
        Returns:
            True if queued successfully, False otherwise
        """
        pass
    
    def set_error_handler(self, handler: Callable):
        """Set custom error handler for collector errors."""
        self._error_handler = handler
    
    def set_degraded_mode(self, degraded: bool):
        """Enable or disable degraded mode."""
        self._degraded_mode = degraded
    
    def handle_error(self, error: Exception):
        """Handle errors using configured handler or default behavior."""
        if self._error_handler:
            self._error_handler(error)
        else:
            # Default: log and continue in degraded mode
            self.set_degraded_mode(True)
    
    def health_check(self) -> Dict[str, Any]:
        """
        Return collector health status.
        
        Returns:
            Dict with health indicators (status, degraded_mode, etc.)
        """
        return {
            "status": "healthy" if not self._degraded_mode else "degraded",
            "position": self.position.value,
            "degraded_mode": self._degraded_mode
        }


def compute_content_hash(content: bytes) -> str:
    """
    Compute SHA-256 hash of content for request correlation.
    
    Args:
        content: Raw content bytes
        
    Returns:
        Hexadecimal hash string
    """
    return hashlib.sha256(content).hexdigest()


def sanitize_headers(headers: Dict[str, str]) -> Dict[str, str]:
    """
    Sanitize headers by removing sensitive information.
    
    Args:
        headers: Original headers dictionary
        
    Returns:
        Sanitized headers with sensitive values removed
    """
    sensitive_keys = {'authorization', 'x-api-key', 'api-key', 'token'}
    return {
        k: v if k.lower() not in sensitive_keys else '***REDACTED***'
        for k, v in headers.items()
    }


def extract_client_ip(headers: Dict[str, str], default: str = "unknown") -> str:
    """
    Extract client IP from headers, accounting for proxies.
    
    Args:
        headers: Request headers
        default: Default value if IP not found
        
    Returns:
        Client IP address
    """
    ip_headers = ['x-forwarded-for', 'x-real-ip', 'cf-connecting-ip']
    for header in ip_headers:
        if header in headers:
            return headers[header].split(',')[0].strip()
    return default
