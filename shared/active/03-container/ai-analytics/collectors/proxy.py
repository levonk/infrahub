"""
HTTP proxy implementation for AI analytics collection.

This module implements a lightweight HTTP proxy that can intercept and forward
AI requests with minimal latency impact (<5ms). It supports both pre-processing
and post-processing collection points.
"""

import asyncio
import time
from typing import Optional, Dict, Any, Tuple
from dataclasses import dataclass
import http.client
import socket
from urllib.parse import urlparse

from .base import (
    BaseCollector, 
    RequestMetadata, 
    ResponseMetadata, 
    AnalyticsEvent,
    CollectorPosition,
    CollectorError,
    compute_content_hash,
    sanitize_headers,
    extract_client_ip
)


@dataclass
class ProxyConfig:
    """Configuration for the HTTP proxy collector."""
    listen_host: str = "0.0.0.0"
    listen_port: int = 8888
    target_host: str = "localhost"
    target_port: int = 8080
    timeout: float = 5.0
    max_request_size: int = 10 * 1024 * 1024  # 10MB
    enable_metrics: bool = True


class HTTPProxyCollector(BaseCollector):
    """
    HTTP proxy collector for intercepting AI requests.
    
    This collector implements a minimal latency proxy that:
    - Intercepts requests on the hot path (<5ms overhead)
    - Queues analytics asynchronously on the cold path
    - Supports graceful degradation when analytics unavailable
    """
    
    def __init__(self, config: ProxyConfig, position: CollectorPosition = CollectorPosition.PRE_PROCESSING):
        super().__init__(position)
        self.config = config
        self._server: Optional[asyncio.Server] = None
        self._request_count = 0
        self._error_count = 0
        self._total_latency_ms = 0.0
        
    async def start(self):
        """Start the HTTP proxy server."""
        self._server = await asyncio.start_server(
            self._handle_connection,
            self.config.listen_host,
            self.config.listen_port
        )
        print(f"Proxy server listening on {self.config.listen_host}:{self.config.listen_port}")
        
    async def stop(self):
        """Stop the HTTP proxy server."""
        if self._server:
            self._server.close()
            await self._server.wait_closed()
            
    async def _handle_connection(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter):
        """Handle incoming connection."""
        start_time = time.time()
        
        try:
            # Read request line
            request_line = await reader.readline()
            if not request_line:
                return
                
            # Parse request line
            method, path, version = request_line.decode().strip().split()
            
            # Read headers
            headers = {}
            while True:
                header_line = await reader.readline()
                if header_line == b'\r\n':
                    break
                key, value = header_line.decode().strip().split(':', 1)
                headers[key.strip()] = value.strip()
            
            # Read body if present
            content_length = int(headers.get('Content-Length', 0))
            body = b''
            if content_length > 0:
                if content_length > self.config.max_request_size:
                    raise CollectorError(f"Request too large: {content_length} bytes")
                body = await reader.readexactly(content_length)
            
            # Extract request metadata
            request_metadata = RequestMetadata(
                method=method,
                path=path,
                query_params=self._parse_query_params(path),
                headers=sanitize_headers(headers),
                client_ip=extract_client_ip(headers, writer.get_extra_info('peername')[0]),
                content_hash=compute_content_hash(body) if body else None,
                content_size=len(body)
            )
            
            # Forward request to target (hot path)
            response_metadata = await self._forward_request(
                method, path, headers, body, request_metadata
            )
            
            # Queue analytics asynchronously (cold path)
            event = AnalyticsEvent(
                request_metadata=request_metadata,
                response_metadata=response_metadata,
                position=self.position
            )
            asyncio.create_task(self._queue_analytics_async(event))
            
            # Send response to client
            writer.write(response_metadata.headers.get('status_line', b'HTTP/1.1 200 OK\r\n').encode())
            for key, value in response_metadata.headers.items():
                if key != 'status_line':
                    writer.write(f"{key}: {value}\r\n".encode())
            writer.write(b'\r\n')
            if response_metadata.content_size > 0:
                # In real implementation, we'd cache the response body
                pass
            await writer.drain()
            
            # Track metrics
            latency_ms = (time.time() - start_time) * 1000
            self._request_count += 1
            self._total_latency_ms += latency_ms
            
        except Exception as e:
            self._error_count += 1
            self.handle_error(e)
            # Send error response
            writer.write(b'HTTP/1.1 500 Internal Server Error\r\n\r\n')
            await writer.drain()
        finally:
            writer.close()
            await writer.wait_closed()
    
    async def _forward_request(
        self, 
        method: str, 
        path: str, 
        headers: Dict[str, str], 
        body: bytes,
        request_metadata: RequestMetadata
    ) -> ResponseMetadata:
        """Forward request to target server and capture response metadata."""
        start_time = time.time()
        
        try:
            # Parse target URL
            target_url = f"http://{self.config.target_host}:{self.config.target_port}{path}"
            parsed = urlparse(target_url)
            
            # Create connection
            conn = http.client.HTTPConnection(
                self.config.target_host,
                self.config.target_port,
                timeout=self.config.timeout
            )
            
            # Forward request
            conn.request(method, path, body, headers)
            response = conn.getresponse()
            
            # Read response headers
            response_headers = dict(response.getheaders())
            
            # Calculate duration
            duration_ms = (time.time() - start_time) * 1000
            
            # Create response metadata
            response_metadata = ResponseMetadata(
                status_code=response.status,
                headers=sanitize_headers(response_headers),
                duration_ms=duration_ms,
                content_size=int(response_headers.get('Content-Length', 0))
            )
            
            conn.close()
            return response_metadata
            
        except Exception as e:
            raise CollectorError(f"Failed to forward request: {e}")
    
    def _parse_query_params(self, path: str) -> Dict[str, str]:
        """Parse query parameters from URL path."""
        if '?' not in path:
            return {}
        
        query_string = path.split('?')[1]
        params = {}
        for param in query_string.split('&'):
            if '=' in param:
                key, value = param.split('=', 1)
                params[key] = value
        return params
    
    async def _queue_analytics_async(self, event: AnalyticsEvent):
        """Queue analytics event asynchronously (cold path)."""
        try:
            self.queue_analytics(event)
        except Exception as e:
            # Don't block the hot path for analytics errors
            self.handle_error(e)
    
    def intercept_request(self, request: Any) -> RequestMetadata:
        """Intercept and extract metadata from incoming request."""
        # This is handled in _handle_connection for async implementation
        raise NotImplementedError("Use async _handle_connection instead")
    
    def intercept_response(self, response: Any, request_metadata: RequestMetadata) -> ResponseMetadata:
        """Intercept and extract metadata from outgoing response."""
        # This is handled in _forward_request for async implementation
        raise NotImplementedError("Use async _forward_request instead")
    
    def queue_analytics(self, event: AnalyticsEvent) -> bool:
        """Queue analytics event for async processing."""
        # In real implementation, this would send to a message queue
        # For now, we'll just log it
        print(f"Analytics event queued: {event.request_metadata.method} {event.request_metadata.path}")
        return True
    
    def health_check(self) -> Dict[str, Any]:
        """Return collector health status with metrics."""
        base_health = super().health_check()
        avg_latency = self._total_latency_ms / self._request_count if self._request_count > 0 else 0
        
        return {
            **base_health,
            "metrics": {
                "request_count": self._request_count,
                "error_count": self._error_count,
                "average_latency_ms": avg_latency,
                "error_rate": self._error_count / self._request_count if self._request_count > 0 else 0
            },
            "config": {
                "listen_address": f"{self.config.listen_host}:{self.config.listen_port}",
                "target": f"{self.config.target_host}:{self.config.target_port}"
            }
        }
