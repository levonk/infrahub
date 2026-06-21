"""
Error handling for message queue operations.

This module defines custom exceptions for queue operations,
providing clear error categorization and handling.
"""


class QueueError(Exception):
    """Base exception for queue operations."""
    pass


class QueueConnectionError(QueueError):
    """Raised when queue connection fails."""
    pass


class QueueSerializationError(QueueError):
    """Raised when message serialization fails."""
    pass


class QueueDeserializationError(QueueError):
    """Raised when message deserialization fails."""
    pass


class QueueFullError(QueueError):
    """Raised when queue is at capacity."""
    pass


class QueueTimeoutError(QueueError):
    """Raised when queue operation times out."""
    pass


class QueueMessageTooLargeError(QueueError):
    """Raised when message exceeds size limit."""
    pass


class QueueRetryExhaustedError(QueueError):
    """Raised when message retry limit is exceeded."""
    pass


class QueueDeadLetterError(QueueError):
    """Raised when message is sent to dead letter queue."""
    pass


class QueueConsumerGroupError(QueueError):
    """Raised when consumer group operation fails."""
    pass


class QueueHealthCheckError(QueueError):
    """Raised when health check fails."""
    pass
