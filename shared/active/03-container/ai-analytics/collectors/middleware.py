"""
Request/response interception middleware for AI analytics collection.

This module provides middleware components for intercepting and processing
HTTP requests and responses in the analytics pipeline.
"""

from typing import Callable, Optional, Dict, Any, List
from dataclasses import dataclass
import time
import re

from .base import (
    RequestMetadata,
    ResponseMetadata,
    AnalyticsEvent,
    CollectorPosition,
    CollectorError
)


@dataclass
class MiddlewareConfig:
    """Configuration for middleware components."""
    max_body_size: int = 10 * 1024 * 1024  # 10MB
    sensitive_headers: List[str] = None
    redact_patterns: List[str] = None
    
    def __post_init__(self):
        if self.sensitive_headers is None:
            self.sensitive_headers = [
                'authorization', 'x-api-key', 'api-key', 'token',
                'password', 'secret', 'credential'
            ]
        if self.redact_patterns is None:
            self.redact_patterns = [
                r'Bearer\s+[A-Za-z0-9\-._~+/]+=*',  # Bearer tokens
                r'api[_-]?key["\']?\s*[:=]\s*["\']?[A-Za-z0-9\-._~+/]+',  # API keys
                r'secret["\']?\s*[:=]\s*["\']?[A-Za-z0-9\-._~+/]+'  # Secrets
            ]


class RequestInterceptor:
    """
    Interceptor for incoming HTTP requests.
    
    Extracts metadata and performs preprocessing on requests before
    they are forwarded to the target service.
    """
    
    def __init__(self, config: Optional[MiddlewareConfig] = None):
        self.config = config or MiddlewareConfig()
        self._preprocessors: List[Callable] = []
        
    def add_preprocessor(self, processor: Callable):
        """Add a request preprocessor function."""
        self._preprocessors.append(processor)
        
    def intercept(self, raw_request: Any) -> RequestMetadata:
        """
        Intercept and extract metadata from raw request.
        
        Args:
            raw_request: The raw request object (framework-specific)
            
        Returns:
            RequestMetadata with extracted information
        """
        start_time = time.time()
        
        try:
            # Extract basic request information
            metadata = self._extract_metadata(raw_request)
            
            # Apply preprocessors
            for processor in self._preprocessors:
                metadata = processor(metadata)
            
            # Validate request size
            if metadata.content_size > self.config.max_body_size:
                raise CollectorError(f"Request body too large: {metadata.content_size} bytes")
            
            return metadata
            
        except Exception as e:
            raise CollectorError(f"Request interception failed: {e}")
    
    def _extract_metadata(self, raw_request: Any) -> RequestMetadata:
        """Extract metadata from raw request object."""
        # This is a placeholder - real implementation would depend on framework
        # For now, we'll return a basic metadata structure
        return RequestMetadata(
            method="GET",
            path="/",
            headers={},
            query_params={},
            client_ip="unknown"
        )


class ResponseInterceptor:
    """
    Interceptor for outgoing HTTP responses.
    
    Extracts metadata and performs postprocessing on responses before
    they are returned to the client.
    """
    
    def __init__(self, config: Optional[MiddlewareConfig] = None):
        self.config = config or MiddlewareConfig()
        self._postprocessors: List[Callable] = []
        
    def add_postprocessor(self, processor: Callable):
        """Add a response postprocessor function."""
        self._postprocessors.append(processor)
        
    def intercept(
        self, 
        raw_response: Any, 
        request_metadata: RequestMetadata
    ) -> ResponseMetadata:
        """
        Intercept and extract metadata from raw response.
        
        Args:
            raw_response: The raw response object (framework-specific)
            request_metadata: Original request metadata for correlation
            
        Returns:
            ResponseMetadata with extracted information
        """
        start_time = time.time()
        
        try:
            # Extract basic response information
            metadata = self._extract_metadata(raw_response)
            
            # Calculate duration
            metadata.duration_ms = (time.time() - request_metadata.timestamp) * 1000
            
            # Apply postprocessors
            for processor in self._postprocessors:
                metadata = processor(metadata)
            
            return metadata
            
        except Exception as e:
            raise CollectorError(f"Response interception failed: {e}")
    
    def _extract_metadata(self, raw_response: Any) -> ResponseMetadata:
        """Extract metadata from raw response object."""
        # This is a placeholder - real implementation would depend on framework
        # For now, we'll return a basic metadata structure
        return ResponseMetadata(
            status_code=200,
            headers={},
            content_size=0
        )


class MiddlewareChain:
    """
    Chain of middleware processors for request/response pipeline.
    
    Allows multiple middleware components to be composed together
    in a processing pipeline.
    """
    
    def __init__(self):
        self._request_middlewares: List[Callable] = []
        self._response_middlewares: List[Callable] = []
        
    def add_request_middleware(self, middleware: Callable):
        """Add request middleware to the chain."""
        self._request_middlewares.append(middleware)
        
    def add_response_middleware(self, middleware: Callable):
        """Add response middleware to the chain."""
        self._response_middlewares.append(middleware)
        
    async def process_request(self, request: Any) -> Any:
        """Process request through the middleware chain."""
        for middleware in self._request_middlewares:
            request = await middleware(request)
        return request
        
    async def process_response(self, response: Any) -> Any:
        """Process response through the middleware chain."""
        for middleware in self._response_middlewares:
            response = await middleware(response)
        return response


class ContentSanitizer:
    """
    Sanitizes request/response content to remove sensitive information.
    
    Uses pattern matching to redact sensitive data like API keys,
    tokens, and credentials from logs and analytics.
    """
    
    def __init__(self, config: Optional[MiddlewareConfig] = None):
        self.config = config or MiddlewareConfig()
        self._compiled_patterns = [
            re.compile(pattern, re.IGNORECASE)
            for pattern in self.config.redact_patterns
        ]
        
    def sanitize(self, content: str) -> str:
        """
        Sanitize content by redacting sensitive information.
        
        Args:
            content: Raw content string
            
        Returns:
            Sanitized content with sensitive data redacted
        """
        sanitized = content
        for pattern in self._compiled_patterns:
            sanitized = pattern.sub('[REDACTED]', sanitized)
        return sanitized
        
    def sanitize_dict(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Sanitize dictionary values recursively.
        
        Args:
            data: Dictionary with potentially sensitive values
            
        Returns:
            Sanitized dictionary
        """
        sanitized = {}
        for key, value in data.items():
            if key.lower() in [h.lower() for h in self.config.sensitive_headers]:
                sanitized[key] = '[REDACTED]'
            elif isinstance(value, str):
                sanitized[key] = self.sanitize(value)
            elif isinstance(value, dict):
                sanitized[key] = self.sanitize_dict(value)
            elif isinstance(value, list):
                sanitized[key] = [
                    self.sanitize_dict(item) if isinstance(item, dict) else
                    self.sanitize(item) if isinstance(item, str) else item
                    for item in value
                ]
            else:
                sanitized[key] = value
        return sanitized
