"""
Configuration for Redis-based message queue in AI analytics pipeline.

This module defines configuration parameters for the message queue system,
including connection settings, performance tuning, and monitoring thresholds.
"""

from dataclasses import dataclass
from typing import Optional


@dataclass
class RedisConfig:
    """Configuration for Redis connection."""
    host: str = "localhost"
    port: int = 6379
    db: int = 0
    password: Optional[str] = None
    socket_timeout: float = 5.0
    socket_connect_timeout: float = 5.0
    retry_on_timeout: bool = True
    max_connections: int = 50
    health_check_interval: int = 30


@dataclass
class QueueConfig:
    """Configuration for message queue behavior."""
    stream_name: str = "analytics_events"
    consumer_group: str = "analytics_processors"
    max_message_size: int = 1024 * 1024  # 1MB
    max_message_age: int = 86400 * 7  # 7 days in milliseconds
    batch_size: int = 10
    block_timeout_ms: int = 5000
    max_retries: int = 3
    retry_backoff_ms: int = 1000
    dead_letter_stream: str = "analytics_events_dlq"


@dataclass
class ProcessorConfig:
    """Configuration for background processor."""
    worker_count: int = 4
    worker_timeout: float = 30.0
    graceful_shutdown_timeout: float = 10.0
    queue_depth_warning_threshold: int = 1000
    queue_depth_critical_threshold: int = 5000


@dataclass
class QueueSystemConfig:
    """Complete configuration for the queue system."""
    redis: RedisConfig = None
    queue: QueueConfig = None
    processor: ProcessorConfig = None
    
    def __post_init__(self):
        if self.redis is None:
            self.redis = RedisConfig()
        if self.queue is None:
            self.queue = QueueConfig()
        if self.processor is None:
            self.processor = ProcessorConfig()
    
    @classmethod
    def from_env(cls) -> 'QueueSystemConfig':
        """Create configuration from environment variables."""
        import os
        
        redis_config = RedisConfig(
            host=os.getenv("REDIS_HOST", "localhost"),
            port=int(os.getenv("REDIS_PORT", "6379")),
            db=int(os.getenv("REDIS_DB", "0")),
            password=os.getenv("REDIS_PASSWORD"),
            socket_timeout=float(os.getenv("REDIS_SOCKET_TIMEOUT", "5.0")),
            socket_connect_timeout=float(os.getenv("REDIS_SOCKET_CONNECT_TIMEOUT", "5.0")),
            max_connections=int(os.getenv("REDIS_MAX_CONNECTIONS", "50"))
        )
        
        queue_config = QueueConfig(
            stream_name=os.getenv("QUEUE_STREAM_NAME", "analytics_events"),
            consumer_group=os.getenv("QUEUE_CONSUMER_GROUP", "analytics_processors"),
            max_message_size=int(os.getenv("QUEUE_MAX_MESSAGE_SIZE", str(1024 * 1024))),
            batch_size=int(os.getenv("QUEUE_BATCH_SIZE", "10")),
            max_retries=int(os.getenv("QUEUE_MAX_RETRIES", "3"))
        )
        
        processor_config = ProcessorConfig(
            worker_count=int(os.getenv("PROCESSOR_WORKER_COUNT", "4")),
            worker_timeout=float(os.getenv("PROCESSOR_WORKER_TIMEOUT", "30.0")),
            queue_depth_warning_threshold=int(os.getenv("PROCESSOR_QUEUE_WARNING", "1000")),
            queue_depth_critical_threshold=int(os.getenv("PROCESSOR_QUEUE_CRITICAL", "5000"))
        )
        
        return cls(redis=redis_config, queue=queue_config, processor=processor_config)
