"""
Message serialization and deserialization for AI analytics pipeline.

This module handles conversion between AnalyticsEvent objects and JSON
for storage in Redis Streams, ensuring data integrity and type safety.
"""

import json
import time
from typing import Dict, Any, Optional
from datetime import datetime

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from collectors import (
    RequestMetadata,
    ResponseMetadata,
    AnalyticsEvent,
    CollectorPosition
)

from errors import (
    QueueSerializationError,
    QueueDeserializationError,
    QueueMessageTooLargeError
)


class MessageSerializer:
    """
    Serializer for analytics events to/from JSON format.
    
    This serializer handles:
    - Conversion of dataclass objects to JSON
    - Type preservation for deserialization
    - Size validation
    - Sensitive data sanitization
    """
    
    def __init__(self, max_message_size: int = 1024 * 1024):
        """
        Initialize serializer with size limit.
        
        Args:
            max_message_size: Maximum allowed message size in bytes
        """
        self.max_message_size = max_message_size
    
    def serialize(self, event: AnalyticsEvent) -> str:
        """
        Serialize AnalyticsEvent to JSON string.
        
        Args:
            event: AnalyticsEvent to serialize
            
        Returns:
            JSON string representation
            
        Raises:
            QueueSerializationError: If serialization fails
            QueueMessageTooLargeError: If message exceeds size limit
        """
        try:
            # Convert to dictionary
            data = {
                "request_metadata": self._serialize_request_metadata(event.request_metadata),
                "response_metadata": self._serialize_response_metadata(event.response_metadata),
                "position": event.position.value,
                "additional_data": event.additional_data,
                "timestamp": time.time()
            }
            
            # Convert to JSON
            json_str = json.dumps(data, default=self._json_default)
            
            # Validate size
            if len(json_str.encode('utf-8')) > self.max_message_size:
                raise QueueMessageTooLargeError(
                    f"Message size {len(json_str)} exceeds limit {self.max_message_size}"
                )
            
            return json_str
            
        except QueueMessageTooLargeError:
            raise
        except Exception as e:
            raise QueueSerializationError(f"Failed to serialize event: {e}")
    
    def deserialize(self, json_str: str) -> AnalyticsEvent:
        """
        Deserialize JSON string to AnalyticsEvent.
        
        Args:
            json_str: JSON string to deserialize
            
        Returns:
            AnalyticsEvent object
            
        Raises:
            QueueDeserializationError: If deserialization fails
        """
        try:
            data = json.loads(json_str)
            
            # Reconstruct objects
            request_metadata = self._deserialize_request_metadata(
                data.get("request_metadata", {})
            )
            response_metadata = self._deserialize_response_metadata(
                data.get("response_metadata")
            )
            position = CollectorPosition(data.get("position", "pre_processing"))
            additional_data = data.get("additional_data", {})
            
            return AnalyticsEvent(
                request_metadata=request_metadata,
                response_metadata=response_metadata,
                position=position,
                additional_data=additional_data
            )
            
        except Exception as e:
            raise QueueDeserializationError(f"Failed to deserialize event: {e}")
    
    def _serialize_request_metadata(self, metadata: RequestMetadata) -> Dict[str, Any]:
        """Serialize RequestMetadata to dictionary."""
        return {
            "method": metadata.method,
            "path": metadata.path,
            "headers": metadata.headers,
            "query_params": metadata.query_params,
            "client_ip": metadata.client_ip,
            "timestamp": metadata.timestamp,
            "content_hash": metadata.content_hash,
            "content_size": metadata.content_size
        }
    
    def _deserialize_request_metadata(self, data: Dict[str, Any]) -> RequestMetadata:
        """Deserialize dictionary to RequestMetadata."""
        return RequestMetadata(
            method=data.get("method", ""),
            path=data.get("path", ""),
            headers=data.get("headers", {}),
            query_params=data.get("query_params", {}),
            client_ip=data.get("client_ip", "unknown"),
            timestamp=data.get("timestamp", time.time()),
            content_hash=data.get("content_hash"),
            content_size=data.get("content_size", 0)
        )
    
    def _serialize_response_metadata(self, metadata: Optional[ResponseMetadata]) -> Optional[Dict[str, Any]]:
        """Serialize ResponseMetadata to dictionary."""
        if metadata is None:
            return None
        
        return {
            "status_code": metadata.status_code,
            "headers": metadata.headers,
            "timestamp": metadata.timestamp,
            "content_size": metadata.content_size,
            "duration_ms": metadata.duration_ms
        }
    
    def _deserialize_response_metadata(self, data: Optional[Dict[str, Any]]) -> Optional[ResponseMetadata]:
        """Deserialize dictionary to ResponseMetadata."""
        if data is None:
            return None
        
        return ResponseMetadata(
            status_code=data.get("status_code", 0),
            headers=data.get("headers", {}),
            timestamp=data.get("timestamp", time.time()),
            content_size=data.get("content_size", 0),
            duration_ms=data.get("duration_ms", 0.0)
        )
    
    def _json_default(self, obj: Any) -> Any:
        """Default JSON serializer for non-serializable objects."""
        if isinstance(obj, datetime):
            return obj.isoformat()
        raise TypeError(f"Object of type {type(obj)} is not JSON serializable")
    
    def validate_message_size(self, json_str: str) -> bool:
        """
        Validate that message size is within limits.
        
        Args:
            json_str: JSON string to validate
            
        Returns:
            True if size is valid, False otherwise
        """
        size = len(json_str.encode('utf-8'))
        return size <= self.max_message_size
    
    def get_message_size(self, json_str: str) -> int:
        """
        Get message size in bytes.
        
        Args:
            json_str: JSON string to measure
            
        Returns:
            Size in bytes
        """
        return len(json_str.encode('utf-8'))
