"""
Unit tests for content hashing utilities.
"""

import pytest
import json

from ..hashing import (
    compute_content_hash,
    compute_request_hash,
    compute_response_hash,
    compute_correlation_id,
    HashCache
)


class TestComputeContentHash:
    """Test compute_content_hash function."""
    
    def test_hash_bytes(self):
        """Test hashing bytes."""
        content = b"test content"
        hash_value = compute_content_hash(content)
        
        assert isinstance(hash_value, str)
        assert len(hash_value) == 64
    
    def test_hash_string(self):
        """Test hashing string."""
        content = "test content"
        hash_value = compute_content_hash(content)
        
        assert isinstance(hash_value, str)
        assert len(hash_value) == 64
    
    def test_hash_dict(self):
        """Test hashing dictionary."""
        content = {"key": "value", "number": 123}
        hash_value = compute_content_hash(content)
        
        assert isinstance(hash_value, str)
        assert len(hash_value) == 64
    
    def test_hash_consistency(self):
        """Test that same content produces same hash."""
        content = b"test content"
        hash1 = compute_content_hash(content)
        hash2 = compute_content_hash(content)
        
        assert hash1 == hash2
    
    def test_hash_uniqueness(self):
        """Test that different content produces different hashes."""
        content1 = b"content 1"
        content2 = b"content 2"
        
        hash1 = compute_content_hash(content1)
        hash2 = compute_content_hash(content2)
        
        assert hash1 != hash2


class TestComputeRequestHash:
    """Test compute_request_hash function."""
    
    def test_request_hash_basic(self):
        """Test basic request hash computation."""
        hash_value = compute_request_hash(
            method="POST",
            path="/api/v1/chat",
            headers={'content-type': 'application/json'},
            body=b'{"test": "data"}'
        )
        
        assert isinstance(hash_value, str)
        assert len(hash_value) == 64
    
    def test_request_hash_without_body(self):
        """Test request hash without body."""
        hash_value = compute_request_hash(
            method="GET",
            path="/api/v1/chat",
            headers={'content-type': 'application/json'}
        )
        
        assert isinstance(hash_value, str)
        assert len(hash_value) == 64
    
    def test_request_hash_header_normalization(self):
        """Test that headers are normalized for hashing."""
        hash1 = compute_request_hash(
            method="GET",
            path="/api/v1/chat",
            headers={'Content-Type': 'application/json'}
        )
        
        hash2 = compute_request_hash(
            method="GET",
            path="/api/v1/chat",
            headers={'content-type': 'application/json'}
        )
        
        assert hash1 == hash2
    
    def test_request_hash_consistency(self):
        """Test that same request produces same hash."""
        hash1 = compute_request_hash(
            method="POST",
            path="/api/v1/chat",
            headers={'content-type': 'application/json'},
            body=b'{"test": "data"}'
        )
        
        hash2 = compute_request_hash(
            method="POST",
            path="/api/v1/chat",
            headers={'content-type': 'application/json'},
            body=b'{"test": "data"}'
        )
        
        assert hash1 == hash2


class TestComputeResponseHash:
    """Test compute_response_hash function."""
    
    def test_response_hash_basic(self):
        """Test basic response hash computation."""
        hash_value = compute_response_hash(
            status_code=200,
            headers={'content-type': 'application/json'},
            body=b'{"result": "ok"}'
        )
        
        assert isinstance(hash_value, str)
        assert len(hash_value) == 64
    
    def test_response_hash_without_body(self):
        """Test response hash without body."""
        hash_value = compute_response_hash(
            status_code=200,
            headers={'content-type': 'application/json'}
        )
        
        assert isinstance(hash_value, str)
        assert len(hash_value) == 64
    
    def test_response_hash_consistency(self):
        """Test that same response produces same hash."""
        hash1 = compute_response_hash(
            status_code=200,
            headers={'content-type': 'application/json'},
            body=b'{"result": "ok"}'
        )
        
        hash2 = compute_response_hash(
            status_code=200,
            headers={'content-type': 'application/json'},
            body=b'{"result": "ok"}'
        )
        
        assert hash1 == hash2


class TestComputeCorrelationId:
    """Test compute_correlation_id function."""
    
    def test_correlation_id_with_response(self):
        """Test correlation ID with both request and response."""
        request_hash = "abc123"
        response_hash = "def456"
        
        correlation_id = compute_correlation_id(request_hash, response_hash)
        
        assert isinstance(correlation_id, str)
        assert len(correlation_id) == 64
    
    def test_correlation_id_without_response(self):
        """Test correlation ID with only request."""
        request_hash = "abc123"
        
        correlation_id = compute_correlation_id(request_hash)
        
        assert isinstance(correlation_id, str)
        assert len(correlation_id) == 64
    
    def test_correlation_id_consistency(self):
        """Test that same inputs produce same correlation ID."""
        request_hash = "abc123"
        response_hash = "def456"
        
        id1 = compute_correlation_id(request_hash, response_hash)
        id2 = compute_correlation_id(request_hash, response_hash)
        
        assert id1 == id2


class TestHashCache:
    """Test HashCache class."""
    
    def test_cache_initialization(self):
        """Test cache initialization."""
        cache = HashCache(max_size=100)
        
        assert cache._max_size == 100
        assert len(cache._cache) == 0
        assert cache._hits == 0
        assert cache._misses == 0
    
    def test_cache_hit(self):
        """Test cache hit."""
        cache = HashCache()
        content = b"test content"
        
        # First call - miss
        hash1 = cache.get_hash(content)
        assert cache._misses == 1
        assert cache._hits == 0
        
        # Second call - hit
        hash2 = cache.get_hash(content)
        assert cache._misses == 1
        assert cache._hits == 1
        assert hash1 == hash2
    
    def test_cache_miss(self):
        """Test cache miss."""
        cache = HashCache()
        
        content1 = b"content 1"
        content2 = b"content 2"
        
        cache.get_hash(content1)
        cache.get_hash(content2)
        
        assert cache._misses == 2
        assert cache._hits == 0
    
    def test_cache_eviction(self):
        """Test cache eviction when max size reached."""
        cache = HashCache(max_size=2)
        
        # Add items up to max size
        cache.get_hash(b"content 1")
        cache.get_hash(b"content 2")
        assert len(cache._cache) == 2
        
        # Add one more - should evict first item
        cache.get_hash(b"content 3")
        assert len(cache._cache) == 2
    
    def test_cache_stats(self):
        """Test cache statistics."""
        cache = HashCache()
        
        content = b"test content"
        cache.get_hash(content)
        cache.get_hash(content)
        cache.get_hash(content)
        
        stats = cache.get_stats()
        
        assert stats['size'] == 1
        assert stats['hits'] == 2
        assert stats['misses'] == 1
        assert stats['hit_rate'] == 2/3
    
    def test_cache_clear(self):
        """Test cache clearing."""
        cache = HashCache()
        
        cache.get_hash(b"content 1")
        cache.get_hash(b"content 2")
        assert len(cache._cache) == 2
        
        cache.clear()
        
        assert len(cache._cache) == 0
        assert cache._hits == 0
        assert cache._misses == 0
    
    def test_cache_different_content_types(self):
        """Test cache with different content types."""
        cache = HashCache()
        
        # Bytes
        hash1 = cache.get_hash(b"bytes content")
        
        # String
        hash2 = cache.get_hash("string content")
        
        # Dict
        hash3 = cache.get_hash({"key": "value"})
        
        assert cache._misses == 3
        assert cache._hits == 0
        assert isinstance(hash1, str)
        assert isinstance(hash2, str)
        assert isinstance(hash3, str)
