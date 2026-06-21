"""Tests for queue configuration."""

import pytest
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from queue.config import (
    RedisConfig,
    QueueConfig,
    ProcessorConfig,
    QueueSystemConfig
)


def test_redis_config_defaults():
    """Test RedisConfig default values."""
    config = RedisConfig()
    assert config.host == "localhost"
    assert config.port == 6379
    assert config.db == 0
    assert config.password is None
    assert config.socket_timeout == 5.0
    assert config.max_connections == 50


def test_queue_config_defaults():
    """Test QueueConfig default values."""
    config = QueueConfig()
    assert config.stream_name == "analytics_events"
    assert config.consumer_group == "analytics_processors"
    assert config.max_message_size == 1024 * 1024
    assert config.batch_size == 10
    assert config.max_retries == 3


def test_processor_config_defaults():
    """Test ProcessorConfig default values."""
    config = ProcessorConfig()
    assert config.worker_count == 4
    assert config.worker_timeout == 30.0
    assert config.queue_depth_warning_threshold == 1000
    assert config.queue_depth_critical_threshold == 5000


def test_queue_system_config_defaults():
    """Test QueueSystemConfig default values."""
    config = QueueSystemConfig()
    assert config.redis is not None
    assert config.queue is not None
    assert config.processor is not None
    assert isinstance(config.redis, RedisConfig)
    assert isinstance(config.queue, QueueConfig)
    assert isinstance(config.processor, ProcessorConfig)


def test_queue_system_config_from_env():
    """Test QueueSystemConfig from environment variables."""
    # Set environment variables
    os.environ["REDIS_HOST"] = "test-host"
    os.environ["REDIS_PORT"] = "6380"
    os.environ["QUEUE_STREAM_NAME"] = "test-stream"
    os.environ["PROCESSOR_WORKER_COUNT"] = "8"
    
    try:
        config = QueueSystemConfig.from_env()
        assert config.redis.host == "test-host"
        assert config.redis.port == 6380
        assert config.queue.stream_name == "test-stream"
        assert config.processor.worker_count == 8
    finally:
        # Clean up
        del os.environ["REDIS_HOST"]
        del os.environ["REDIS_PORT"]
        del os.environ["QUEUE_STREAM_NAME"]
        del os.environ["PROCESSOR_WORKER_COUNT"]


def test_queue_system_config_custom():
    """Test QueueSystemConfig with custom configs."""
    redis_config = RedisConfig(host="custom-host", port=6380)
    queue_config = QueueConfig(stream_name="custom-stream")
    processor_config = ProcessorConfig(worker_count=8)
    
    config = QueueSystemConfig(
        redis=redis_config,
        queue=queue_config,
        processor=processor_config
    )
    
    assert config.redis.host == "custom-host"
    assert config.redis.port == 6380
    assert config.queue.stream_name == "custom-stream"
    assert config.processor.worker_count == 8
