"""
Content hashing utilities for request correlation in AI analytics pipeline.

This module provides utilities for computing content hashes to correlate
requests and responses across the analytics pipeline.
"""

import hashlib
import json
from typing import Union, Dict, Any, Optional


def compute_content_hash(content: Union[bytes, str, Dict[str, Any]]) -> str:
    """
    Compute SHA-256 hash of content for request correlation.
    
    Args:
        content: Raw content as bytes, string, or dictionary
        
    Returns:
        Hexadecimal hash string
    """
    if isinstance(content, dict):
        content = json.dumps(content, sort_keys=True)
    elif isinstance(content, str):
        content = content.encode('utf-8')
    elif not isinstance(content, bytes):
        content = str(content).encode('utf-8')
    
    return hashlib.sha256(content).hexdigest()


def compute_request_hash(
    method: str,
    path: str,
    headers: Dict[str, str],
    body: Optional[bytes] = None
) -> str:
    """
    Compute hash for request correlation.
    
    Combines method, path, headers, and body to create a unique
    identifier for the request.
    
    Args:
        method: HTTP method
        path: Request path
        headers: Request headers
        body: Request body (optional)
        
    Returns:
        Hexadecimal hash string
    """
    # Normalize headers for consistent hashing
    normalized_headers = {k.lower(): v for k, v in headers.items()}
    
    # Create hash input
    hash_input = {
        'method': method,
        'path': path,
        'headers': normalized_headers
    }
    
    if body:
        hash_input['body_hash'] = compute_content_hash(body)
    
    return compute_content_hash(hash_input)


def compute_response_hash(
    status_code: int,
    headers: Dict[str, str],
    body: Optional[bytes] = None
) -> str:
    """
    Compute hash for response correlation.
    
    Args:
        status_code: HTTP status code
        headers: Response headers
        body: Response body (optional)
        
    Returns:
        Hexadecimal hash string
    """
    # Normalize headers for consistent hashing
    normalized_headers = {k.lower(): v for k, v in headers.items()}
    
    # Create hash input
    hash_input = {
        'status_code': status_code,
        'headers': normalized_headers
    }
    
    if body:
        hash_input['body_hash'] = compute_content_hash(body)
    
    return compute_content_hash(hash_input)


def compute_correlation_id(
    request_hash: str,
    response_hash: Optional[str] = None
) -> str:
    """
    Compute correlation ID for request-response pair.
    
    Args:
        request_hash: Hash of the request
        response_hash: Hash of the response (optional)
        
    Returns:
        Correlation ID string
    """
    if response_hash:
        combined = f"{request_hash}:{response_hash}"
    else:
        combined = request_hash
    
    return compute_content_hash(combined)


class HashCache:
    """
    Cache for computed hashes to avoid redundant computation.
    
    Useful for scenarios where the same content might be hashed
    multiple times (e.g., during retries or deduplication).
    """
    
    def __init__(self, max_size: int = 10000):
        self._cache: Dict[str, str] = {}
        self._max_size = max_size
        self._hits = 0
        self._misses = 0
        
    def get_hash(self, content: Union[bytes, str, Dict[str, Any]]) -> str:
        """
        Get hash from cache or compute if not present.
        
        Args:
            content: Content to hash
            
        Returns:
            Hexadecimal hash string
        """
        cache_key = self._make_cache_key(content)
        
        if cache_key in self._cache:
            self._hits += 1
            return self._cache[cache_key]
        
        self._misses += 1
        hash_value = compute_content_hash(content)
        
        # Add to cache with size management
        if len(self._cache) >= self._max_size:
            # Simple eviction: remove first item
            self._cache.pop(next(iter(self._cache)))
        
        self._cache[cache_key] = hash_value
        return hash_value
    
    def _make_cache_key(self, content: Union[bytes, str, Dict[str, Any]]) -> str:
        """Create cache key from content."""
        if isinstance(content, bytes):
            return f"bytes:{len(content)}:{content[:100]}"
        elif isinstance(content, str):
            return f"str:{len(content)}:{content[:100]}"
        elif isinstance(content, dict):
            return f"dict:{json.dumps(content, sort_keys=True)[:100]}"
        else:
            return f"other:{str(content)[:100]}"
    
    def get_stats(self) -> Dict[str, Any]:
        """Get cache statistics."""
        total_requests = self._hits + self._misses
        hit_rate = self._hits / total_requests if total_requests > 0 else 0
        
        return {
            'size': len(self._cache),
            'max_size': self._max_size,
            'hits': self._hits,
            'misses': self._misses,
            'hit_rate': hit_rate
        }
    
    def clear(self):
        """Clear the cache."""
        self._cache.clear()
        self._hits = 0
        self._misses = 0
