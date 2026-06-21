"""
Unit tests for base collector functionality.
"""

import pytest
from unittest.mock import Mock
from datetime import datetime

from ..base import (
    RequestMetadata,
    ResponseMetadata,
    AnalyticsEvent,
    CollectorPosition,
    BaseCollector,
    CollectorError,
    compute_content_hash,
    sanitize_headers,
    extract_client_ip
)


class TestRequestMetadata:
    """Test RequestMetadata dataclass."""
    
    def test_request_metadata_creation(self):
        """Test creating request metadata."""
        metadata = RequestMetadata(
            method="POST",
            path="/api/v1/chat",
            headers={'content-type': 'application/json'},
            query_params={'param': 'value'},
            client_ip="192.168.1.1"
        )
        
        assert metadata.method == "POST"
        assert metadata.path == "/api/v1/chat"
        assert metadata.headers['content-type'] == 'application/json'
        assert metadata.query_params['param'] == 'value'
        assert metadata.client_ip == "192.168.1.1"
        assert metadata.content_hash is None
        assert metadata.content_size == 0
    
    def test_request_metadata_with_content(self):
        """Test request metadata with content information."""
        metadata = RequestMetadata(
            method="POST",
            path="/api/v1/chat",
            headers={},
            query_params={},
            client_ip="192.168.1.1",
            content_hash="abc123",
            content_size=100
        )
        
        assert metadata.content_hash == "abc123"
        assert metadata.content_size == 100


class TestResponseMetadata:
    """Test ResponseMetadata dataclass."""
    
    def test_response_metadata_creation(self):
        """Test creating response metadata."""
        metadata = ResponseMetadata(
            status_code=200,
            headers={'content-type': 'application/json'}
        )
        
        assert metadata.status_code == 200
        assert metadata.headers['content-type'] == 'application/json'
        assert metadata.content_size == 0
        assert metadata.duration_ms == 0.0
    
    def test_response_metadata_with_metrics(self):
        """Test response metadata with performance metrics."""
        metadata = ResponseMetadata(
            status_code=200,
            headers={},
            content_size=50,
            duration_ms=15.5
        )
        
        assert metadata.content_size == 50
        assert metadata.duration_ms == 15.5


class TestAnalyticsEvent:
    """Test AnalyticsEvent dataclass."""
    
    def test_analytics_event_creation(self):
        """Test creating analytics event."""
        request_metadata = RequestMetadata(
            method="POST",
            path="/api/v1/chat",
            headers={},
            query_params={},
            client_ip="192.168.1.1"
        )
        
        event = AnalyticsEvent(
            request_metadata=request_metadata,
            position=CollectorPosition.PRE_PROCESSING
        )
        
        assert event.request_metadata == request_metadata
        assert event.response_metadata is None
        assert event.position == CollectorPosition.PRE_PROCESSING
        assert event.additional_data == {}
    
    def test_analytics_event_with_response(self):
        """Test analytics event with response metadata."""
        request_metadata = RequestMetadata(
            method="POST",
            path="/api/v1/chat",
            headers={},
            query_params={},
            client_ip="192.168.1.1"
        )
        
        response_metadata = ResponseMetadata(
            status_code=200,
            headers={},
            content_size=50
        )
        
        event = AnalyticsEvent(
            request_metadata=request_metadata,
            response_metadata=response_metadata,
            position=CollectorPosition.POST_PROCESSING
        )
        
        assert event.response_metadata == response_metadata
        assert event.position == CollectorPosition.POST_PROCESSING


class TestBaseCollector:
    """Test BaseCollector abstract class."""
    
    def test_base_collector_health_check(self):
        """Test base collector health check."""
        collector = Mock(spec=BaseCollector)
        collector.position = CollectorPosition.PRE_PROCESSING
        collector._error_handler = None
        collector._degraded_mode = False
        
        # Call the real health_check method
        from ..base import BaseCollector
        result = BaseCollector.health_check(collector)
        
        assert result['status'] == 'healthy'
        assert result['position'] == 'pre_processing'
        assert result['degraded_mode'] is False
    
    def test_base_collector_degraded_mode(self):
        """Test degraded mode functionality."""
        collector = Mock(spec=BaseCollector)
        collector._error_handler = None
        collector._degraded_mode = False
        
        from ..base import BaseCollector
        BaseCollector.set_degraded_mode(collector, True)
        
        result = BaseCollector.health_check(collector)
        assert result['status'] == 'degraded'
        assert result['degraded_mode'] is True


class TestContentHashing:
    """Test content hashing utilities."""
    
    def test_compute_content_hash_bytes(self):
        """Test hashing bytes content."""
        content = b"test content"
        hash_value = compute_content_hash(content)
        
        assert isinstance(hash_value, str)
        assert len(hash_value) == 64  # SHA-256 produces 64 hex characters
    
    def test_compute_content_hash_string(self):
        """Test hashing string content."""
        content = "test content"
        hash_value = compute_content_hash(content)
        
        assert isinstance(hash_value, str)
        assert len(hash_value) == 64
    
    def test_compute_content_hash_dict(self):
        """Test hashing dictionary content."""
        content = {"key": "value", "number": 123}
        hash_value = compute_content_hash(content)
        
        assert isinstance(hash_value, str)
        assert len(hash_value) == 64
    
    def test_compute_content_hash_consistency(self):
        """Test that same content produces same hash."""
        content = b"test content"
        hash1 = compute_content_hash(content)
        hash2 = compute_content_hash(content)
        
        assert hash1 == hash2
    
    def test_compute_content_hash_uniqueness(self):
        """Test that different content produces different hashes."""
        content1 = b"test content 1"
        content2 = b"test content 2"
        
        hash1 = compute_content_hash(content1)
        hash2 = compute_content_hash(content2)
        
        assert hash1 != hash2


class TestHeaderSanitization:
    """Test header sanitization utilities."""
    
    def test_sanitize_headers_basic(self):
        """Test basic header sanitization."""
        headers = {
            'content-type': 'application/json',
            'user-agent': 'test-agent'
        }
        
        sanitized = sanitize_headers(headers)
        
        assert sanitized == headers
    
    def test_sanitize_headers_sensitive(self):
        """Test sanitization of sensitive headers."""
        headers = {
            'content-type': 'application/json',
            'authorization': 'Bearer secret-token',
            'x-api-key': 'api-key-123',
            'user-agent': 'test-agent'
        }
        
        sanitized = sanitize_headers(headers)
        
        assert sanitized['content-type'] == 'application/json'
        assert sanitized['user-agent'] == 'test-agent'
        assert sanitized['authorization'] == '***REDACTED***'
        assert sanitized['x-api-key'] == '***REDACTED***'
    
    def test_sanitize_headers_case_insensitive(self):
        """Test that header sanitization is case-insensitive."""
        headers = {
            'Authorization': 'Bearer secret-token',
            'X-API-KEY': 'api-key-123'
        }
        
        sanitized = sanitize_headers(headers)
        
        assert sanitized['Authorization'] == '***REDACTED***'
        assert sanitized['X-API-KEY'] == '***REDACTED***'


class TestClientIPExtraction:
    """Test client IP extraction utilities."""
    
    def test_extract_client_ip_from_x_forwarded_for(self):
        """Test extracting IP from X-Forwarded-For header."""
        headers = {'x-forwarded-for': '192.168.1.1, 10.0.0.1'}
        ip = extract_client_ip(headers)
        
        assert ip == '192.168.1.1'
    
    def test_extract_client_ip_from_x_real_ip(self):
        """Test extracting IP from X-Real-IP header."""
        headers = {'x-real-ip': '192.168.1.1'}
        ip = extract_client_ip(headers)
        
        assert ip == '192.168.1.1'
    
    def test_extract_client_ip_from_cf_connecting_ip(self):
        """Test extracting IP from CF-Connecting-IP header."""
        headers = {'cf-connecting-ip': '192.168.1.1'}
        ip = extract_client_ip(headers)
        
        assert ip == '192.168.1.1'
    
    def test_extract_client_ip_default(self):
        """Test default IP when no headers present."""
        headers = {}
        ip = extract_client_ip(headers, default='unknown')
        
        assert ip == 'unknown'
    
    def test_extract_client_ip_priority(self):
        """Test that X-Forwarded-For has priority."""
        headers = {
            'x-forwarded-for': '192.168.1.1',
            'x-real-ip': '10.0.0.1'
        }
        ip = extract_client_ip(headers)
        
        assert ip == '192.168.1.1'
