"""Tests for message serialization."""

import pytest
import json
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from queue.serialization import MessageSerializer
from queue.errors import (
    QueueSerializationError,
    QueueDeserializationError,
    QueueMessageTooLargeError
)

from collectors import (
    RequestMetadata,
    ResponseMetadata,
    AnalyticsEvent,
    CollectorPosition
)


def test_serializer_init():
    """Test serializer initialization."""
    serializer = MessageSerializer()
    assert serializer.max_message_size == 1024 * 1024
    
    serializer = MessageSerializer(max_message_size=512)
    assert serializer.max_message_size == 512


def test_serialize_analytics_event():
    """Test serializing AnalyticsEvent."""
    serializer = MessageSerializer()
    
    request_metadata = RequestMetadata(
        method="POST",
        path="/api/v1/chat",
        headers={"content-type": "application/json"},
        query_params={"model": "gpt-4"},
        client_ip="192.168.1.1",
        content_hash="abc123",
        content_size=100
    )
    
    response_metadata = ResponseMetadata(
        status_code=200,
        headers={"content-type": "application/json"},
        content_size=500,
        duration_ms=150.0
    )
    
    event = AnalyticsEvent(
        request_metadata=request_metadata,
        response_metadata=response_metadata,
        position=CollectorPosition.PRE_PROCESSING,
        additional_data={"test": "data"}
    )
    
    json_str = serializer.serialize(event)
    
    assert isinstance(json_str, str)
    assert json_str  # Not empty
    
    # Verify it's valid JSON
    data = json.loads(json_str)
    assert "request_metadata" in data
    assert "response_metadata" in data
    assert "position" in data


def test_deserialize_analytics_event():
    """Test deserializing AnalyticsEvent."""
    serializer = MessageSerializer()
    
    request_metadata = RequestMetadata(
        method="GET",
        path="/api/v1/models",
        headers={"authorization": "Bearer token"},
        query_params={},
        client_ip="10.0.0.1"
    )
    
    event = AnalyticsEvent(
        request_metadata=request_metadata,
        position=CollectorPosition.POST_PROCESSING
    )
    
    json_str = serializer.serialize(event)
    deserialized_event = serializer.deserialize(json_str)
    
    assert isinstance(deserialized_event, AnalyticsEvent)
    assert deserialized_event.request_metadata.method == "GET"
    assert deserialized_event.request_metadata.path == "/api/v1/models"
    assert deserialized_event.position == CollectorPosition.POST_PROCESSING
    assert deserialized_event.response_metadata is None


def test_serialize_deserialize_roundtrip():
    """Test roundtrip serialization/deserialization."""
    serializer = MessageSerializer()
    
    original_event = AnalyticsEvent(
        request_metadata=RequestMetadata(
            method="POST",
            path="/api/v1/completions",
            headers={"content-type": "application/json"},
            query_params={"model": "gpt-4"},
            client_ip="172.16.0.1",
            content_hash="sha256hash",
            content_size=200
        ),
        response_metadata=ResponseMetadata(
            status_code=200,
            headers={"content-type": "application/json"},
            content_size=1000,
            duration_ms=250.5
        ),
        position=CollectorPosition.PRE_PROCESSING,
        additional_data={"key": "value", "number": 42}
    )
    
    json_str = serializer.serialize(original_event)
    deserialized_event = serializer.deserialize(json_str)
    
    # Verify all fields match
    assert deserialized_event.request_metadata.method == original_event.request_metadata.method
    assert deserialized_event.request_metadata.path == original_event.request_metadata.path
    assert deserialized_event.request_metadata.client_ip == original_event.request_metadata.client_ip
    assert deserialized_event.request_metadata.content_hash == original_event.request_metadata.content_hash
    assert deserialized_event.request_metadata.content_size == original_event.request_metadata.content_size
    
    assert deserialized_event.response_metadata.status_code == original_event.response_metadata.status_code
    assert deserialized_event.response_metadata.content_size == original_event.response_metadata.content_size
    assert deserialized_event.response_metadata.duration_ms == original_event.response_metadata.duration_ms
    
    assert deserialized_event.position == original_event.position
    assert deserialized_event.additional_data == original_event.additional_data


def test_serialize_with_none_response():
    """Test serializing event with None response metadata."""
    serializer = MessageSerializer()
    
    event = AnalyticsEvent(
        request_metadata=RequestMetadata(
            method="GET",
            path="/api/health",
            headers={},
            query_params={},
            client_ip="127.0.0.1"
        ),
        response_metadata=None,
        position=CollectorPosition.PRE_PROCESSING
    )
    
    json_str = serializer.serialize(event)
    deserialized_event = serializer.deserialize(json_str)
    
    assert deserialized_event.response_metadata is None


def test_message_too_large():
    """Test error when message exceeds size limit."""
    serializer = MessageSerializer(max_message_size=100)
    
    event = AnalyticsEvent(
        request_metadata=RequestMetadata(
            method="POST",
            path="/api/v1/test",
            headers={},
            query_params={},
            client_ip="1.2.3.4",
            additional_data={"large_data": "x" * 1000}  # This will exceed limit
        )
    )
    
    with pytest.raises(QueueMessageTooLargeError):
        serializer.serialize(event)


def test_validate_message_size():
    """Test message size validation."""
    serializer = MessageSerializer(max_message_size=100)
    
    small_message = '{"test": "data"}'
    assert serializer.validate_message_size(small_message) is True
    
    large_message = '{"test": "' + "x" * 200 + '"}'
    assert serializer.validate_message_size(large_message) is False


def test_get_message_size():
    """Test getting message size."""
    serializer = MessageSerializer()
    
    message = '{"test": "data"}'
    size = serializer.get_message_size(message)
    
    assert size > 0
    assert isinstance(size, int)


def test_deserialize_invalid_json():
    """Test deserializing invalid JSON."""
    serializer = MessageSerializer()
    
    with pytest.raises(QueueDeserializationError):
        serializer.deserialize("not valid json")


def test_deserialize_missing_fields():
    """Test deserializing JSON with missing fields."""
    serializer = MessageSerializer()
    
    # Missing required fields
    incomplete_json = '{"position": "pre_processing"}'
    
    with pytest.raises(QueueDeserializationError):
        serializer.deserialize(incomplete_json)
