"""
Test framework for AI analytics collectors.

This module provides testing utilities and fixtures for testing
collector components.
"""

import pytest
import asyncio
from typing import AsyncGenerator, Generator
from unittest.mock import Mock, AsyncMock, MagicMock
import tempfile
import os
from pathlib import Path


@pytest.fixture
def event_loop():
    """Create an event loop for async tests."""
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest.fixture
def temp_config_file() -> Generator[Path, None, None]:
    """Create a temporary configuration file."""
    with tempfile.NamedTemporaryFile(mode='w', suffix='.yml', delete=False) as f:
        f.write("""
enabled: true
position: pre_processing
log_level: DEBUG
max_request_size: 10485760
timeout: 5.0
enable_metrics: true
""")
        temp_path = Path(f.name)
    
    yield temp_path
    
    # Cleanup
    if temp_path.exists():
        temp_path.unlink()


@pytest.fixture
def mock_request():
    """Create a mock request object."""
    request = Mock()
    request.method = "GET"
    request.path = "/api/test"
    request.headers = {
        'content-type': 'application/json',
        'user-agent': 'test-agent'
    }
    request.query_params = {'param1': 'value1'}
    request.client_ip = '127.0.0.1'
    request.body = b'{"test": "data"}'
    return request


@pytest.fixture
def mock_response():
    """Create a mock response object."""
    response = Mock()
    response.status_code = 200
    response.headers = {
        'content-type': 'application/json',
        'content-length': '17'
    }
    response.body = b'{"result": "ok"}'
    return response


@pytest.fixture
def sample_analytics_event():
    """Create a sample analytics event."""
    from ..base import RequestMetadata, ResponseMetadata, AnalyticsEvent, CollectorPosition
    
    return AnalyticsEvent(
        request_metadata=RequestMetadata(
            method="POST",
            path="/api/v1/chat",
            headers={'content-type': 'application/json'},
            query_params={},
            client_ip="192.168.1.1",
            content_hash="abc123",
            content_size=100
        ),
        response_metadata=ResponseMetadata(
            status_code=200,
            headers={'content-type': 'application/json'},
            content_size=50,
            duration_ms=15.5
        ),
        position=CollectorPosition.PRE_PROCESSING
    )


class AsyncContextManager:
    """Helper for async context management in tests."""
    
    def __init__(self, obj):
        self.obj = obj
    
    async def __aenter__(self):
        return self.obj
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if hasattr(self.obj, 'close'):
            await self.obj.close()


def create_mock_collector():
    """Create a mock collector for testing."""
    from ..base import BaseCollector, RequestMetadata, ResponseMetadata, AnalyticsEvent
    
    class MockCollector(BaseCollector):
        def __init__(self):
            super().__init__()
            self.events = []
        
        def intercept_request(self, request):
            return RequestMetadata(
                method="GET",
                path="/test",
                headers={},
                query_params={},
                client_ip="127.0.0.1"
            )
        
        def intercept_response(self, response, request_metadata):
            return ResponseMetadata(
                status_code=200,
                headers={},
                content_size=0
            )
        
        def queue_analytics(self, event):
            self.events.append(event)
            return True
    
    return MockCollector()


def create_test_server(port=8765):
    """Create a test HTTP server for integration tests."""
    import http.server
    import socketserver
    import threading
    
    class TestHandler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(b'{"status": "ok"}')
        
        def do_POST(self):
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(b'{"status": "received"}')
        
        def log_message(self, format, *args):
            pass  # Suppress logging
    
    server = socketserver.TCPServer(('localhost', port), TestHandler)
    thread = threading.Thread(target=server.serve_forever)
    thread.daemon = True
    thread.start()
    
    return server, thread


class PerformanceTimer:
    """Helper for timing performance in tests."""
    
    def __init__(self):
        self.start_time = None
        self.end_time = None
    
    def start(self):
        """Start the timer."""
        import time
        self.start_time = time.time()
    
    def stop(self):
        """Stop the timer."""
        import time
        self.end_time = time.time()
    
    def elapsed_ms(self) -> float:
        """Get elapsed time in milliseconds."""
        if self.start_time is None or self.end_time is None:
            return 0.0
        return (self.end_time - self.start_time) * 1000
    
    def __enter__(self):
        self.start()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        self.stop()


def assert_latency_below(threshold_ms: float, actual_ms: float):
    """Assert that latency is below threshold."""
    assert actual_ms < threshold_ms, f"Latency {actual_ms:.2f}ms exceeds threshold {threshold_ms:.2f}ms"


def assert_error_rate_below(threshold: float, error_count: int, total_count: int):
    """Assert that error rate is below threshold."""
    error_rate = error_count / total_count if total_count > 0 else 0
    assert error_rate < threshold, f"Error rate {error_rate:.2%} exceeds threshold {threshold:.2%}"
