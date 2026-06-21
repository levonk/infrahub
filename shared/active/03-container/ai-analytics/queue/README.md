# Message Queue Configuration Guide

This guide provides detailed configuration options for the Redis-based message queue system in the AI analytics pipeline.

## Configuration Overview

The queue system uses three main configuration classes:

1. **RedisConfig** - Redis connection settings
2. **QueueConfig** - Message queue behavior settings
3. **ProcessorConfig** - Background processor settings

## Environment Variables

### Redis Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `REDIS_HOST` | `localhost` | Redis server hostname |
| `REDIS_PORT` | `6379` | Redis server port |
| `REDIS_DB` | `0` | Redis database number |
| `REDIS_PASSWORD` | `None` | Redis authentication password |
| `REDIS_SOCKET_TIMEOUT` | `5.0` | Socket timeout in seconds |
| `REDIS_SOCKET_CONNECT_TIMEOUT` | `5.0` | Connection timeout in seconds |
| `REDIS_MAX_CONNECTIONS` | `50` | Maximum connection pool size |
| `REDIS_HEALTH_CHECK_INTERVAL` | `30` | Health check interval in seconds |

### Queue Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `QUEUE_STREAM_NAME` | `analytics_events` | Redis Stream name |
| `QUEUE_CONSUMER_GROUP` | `analytics_processors` | Consumer group name |
| `QUEUE_MAX_MESSAGE_SIZE` | `1048576` | Max message size in bytes (1MB) |
| `QUEUE_MAX_MESSAGE_AGE` | `604800000` | Max message age in milliseconds (7 days) |
| `QUEUE_BATCH_SIZE` | `10` | Number of messages per batch |
| `QUEUE_BLOCK_TIMEOUT_MS` | `5000` | Block read timeout in milliseconds |
| `QUEUE_MAX_RETRIES` | `3` | Maximum retry attempts |
| `QUEUE_RETRY_BACKOFF_MS` | `1000` | Initial retry backoff in milliseconds |
| `QUEUE_DEAD_LETTER_STREAM` | `analytics_events_dlq` | Dead letter queue stream name |

### Processor Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `PROCESSOR_WORKER_COUNT` | `4` | Number of worker processes |
| `PROCESSOR_WORKER_TIMEOUT` | `30.0` | Worker processing timeout in seconds |
| `PROCESSOR_GRACEFUL_SHUTDOWN_TIMEOUT` | `10.0` | Graceful shutdown timeout in seconds |
| `PROCESSOR_QUEUE_WARNING_THRESHOLD` | `1000` | Queue depth warning threshold |
| `PROCESSOR_QUEUE_CRITICAL_THRESHOLD` | `5000` | Queue depth critical threshold |

## Configuration Examples

### Development Environment

```bash
# Redis configuration
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_DB=0
REDIS_MAX_CONNECTIONS=10

# Queue configuration
QUEUE_STREAM_NAME=analytics_events_dev
QUEUE_BATCH_SIZE=5
QUEUE_MAX_RETRIES=2

# Processor configuration
PROCESSOR_WORKER_COUNT=2
PROCESSOR_QUEUE_WARNING_THRESHOLD=500
```

### Production Environment

```bash
# Redis configuration
REDIS_HOST=redis.internal
REDIS_PORT=6379
REDIS_DB=0
REDIS_PASSWORD=secure_password
REDIS_MAX_CONNECTIONS=50
REDIS_SOCKET_TIMEOUT=10.0

# Queue configuration
QUEUE_STREAM_NAME=analytics_events_prod
QUEUE_BATCH_SIZE=20
QUEUE_MAX_RETRIES=5
QUEUE_RETRY_BACKOFF_MS=2000

# Processor configuration
PROCESSOR_WORKER_COUNT=8
PROCESSOR_WORKER_TIMEOUT=60.0
PROCESSOR_QUEUE_WARNING_THRESHOLD=1000
PROCESSOR_QUEUE_CRITICAL_THRESHOLD=5000
```

### High-Throughput Environment

```bash
# Redis configuration
REDIS_HOST=redis-cluster.internal
REDIS_PORT=6379
REDIS_DB=0
REDIS_PASSWORD=secure_password
REDIS_MAX_CONNECTIONS=100
REDIS_SOCKET_TIMEOUT=5.0

# Queue configuration
QUEUE_STREAM_NAME=analytics_events_highthroughput
QUEUE_BATCH_SIZE=50
QUEUE_MAX_RETRIES=3
QUEUE_BLOCK_TIMEOUT_MS=1000

# Processor configuration
PROCESSOR_WORKER_COUNT=16
PROCESSOR_WORKER_TIMEOUT=30.0
PROCESSOR_QUEUE_WARNING_THRESHOLD=5000
PROCESSOR_QUEUE_CRITICAL_THRESHOLD=20000
```

## Performance Tuning Guidelines

### Throughput Optimization

1. **Increase Batch Size**: Larger batches reduce Redis round-trips
   - Development: 5-10 messages
   - Production: 10-20 messages
   - High-throughput: 20-50 messages

2. **Scale Workers**: More workers process messages in parallel
   - CPU-bound: Set to number of CPU cores
   - I/O-bound: Can exceed CPU cores (2-4x)
   - Monitor worker utilization to avoid over-provisioning

3. **Optimize Redis Connections**: Balance connection pool size
   - Too few: Connection contention
   - Too many: Resource overhead
   - Rule of thumb: 2-3x worker count

### Latency Optimization

1. **Reduce Block Timeout**: Lower timeout for faster response to new messages
   - Development: 5000ms (default)
   - Production: 1000-2000ms
   - Real-time: 100-500ms

2. **Adjust Retry Backoff**: Faster retries for transient failures
   - Development: 1000ms (default)
   - Production: 2000-5000ms
   - Consider exponential backoff

3. **Monitor Processing Time**: Track average processing time
   - Target: <100ms per message
   - If slower: optimize database operations, consider batching

### Memory Optimization

1. **Limit Message Size**: Prevent large messages from consuming memory
   - Default: 1MB
   - Adjust based on typical event size
   - Consider compression for large payloads

2. **Set Message TTL**: Automatically expire old messages
   - Default: 7 days
   - Adjust based on retention requirements
   - Shorter TTL = less memory usage

3. **Monitor Queue Depth**: Alert on queue growth
   - Warning: 1000 messages
   - Critical: 5000 messages
   - Indicates processing bottleneck

## Reliability Configuration

### Connection Reliability

```python
# Enable connection retry
redis_config = RedisConfig(
    retry_on_timeout=True,
    socket_timeout=5.0,
    socket_connect_timeout=5.0
)
```

### Message Reliability

```python
# Increase retries for important messages
queue_config = QueueConfig(
    max_retries=5,
    retry_backoff_ms=2000
)
```

### Dead Letter Queue

```python
# Configure dead letter queue
queue_config = QueueConfig(
    dead_letter_stream="analytics_events_dlq",
    max_message_age=86400000  # 24 hours
)
```

## Monitoring Configuration

### Metrics Collection

The queue system automatically collects metrics:

- Queue depth
- Message production rate
- Message consumption rate
- Error rate
- Retry count
- Dead letter count
- Worker utilization
- Processing latency

### Health Check Thresholds

```python
processor_config = ProcessorConfig(
    queue_depth_warning_threshold=1000,
    queue_depth_critical_threshold=5000
)
```

### Alerting

Monitor these metrics for alerts:

1. **Queue Depth**: Sustained high depth = processing bottleneck
2. **Error Rate**: >5% = system issues
3. **Dead Letter Count**: Growing = persistent failures
4. **Worker Utilization**: >90% = need more workers
5. **Processing Latency**: Increasing = performance degradation

## Scaling Strategies

### Vertical Scaling

Increase resources on single instance:

```python
# More workers
PROCESSOR_WORKER_COUNT=16

# Larger connection pool
REDIS_MAX_CONNECTIONS=100

# Larger batches
QUEUE_BATCH_SIZE=50
```

### Horizontal Scaling

Add more consumer instances:

```python
# Each instance with unique consumer name
consumer_name = f"processor-{hostname}-{instance_id}"
```

### Redis Cluster Scaling

For very high throughput:

```python
# Use Redis Cluster
redis_config = RedisConfig(
    host="redis-cluster-node1.internal"
)

# Shard streams by event type
stream_name = f"analytics_events_{event_type}"
```

## Troubleshooting Configuration

### Common Issues

1. **Connection Timeouts**
   - Increase `REDIS_SOCKET_TIMEOUT`
   - Check network latency
   - Verify Redis server health

2. **High Queue Depth**
   - Increase `PROCESSOR_WORKER_COUNT`
   - Optimize message processing
   - Check database performance

3. **High Error Rate**
   - Review `QUEUE_MAX_RETRIES`
   - Check dead letter queue
   - Verify message serialization

4. **Memory Pressure**
   - Reduce `QUEUE_MAX_MESSAGE_SIZE`
   - Decrease `QUEUE_MAX_MESSAGE_AGE`
   - Monitor Redis memory usage

## Configuration Validation

The system validates configuration on startup:

- Redis connection parameters
- Queue parameter ranges
- Processor resource limits
- Message size constraints

Invalid configuration will prevent startup with clear error messages.

## Default Configuration

```python
from queue.config import QueueSystemConfig

# Load defaults
config = QueueSystemConfig()

# Or from environment
config = QueueSystemConfig.from_env()
```

## Configuration Best Practices

1. **Use Environment Variables**: Keep secrets out of code
2. **Document Custom Values**: Explain why non-defaults were chosen
3. **Test Changes**: Validate in development before production
4. **Monitor Impact**: Watch metrics after configuration changes
5. **Version Control**: Track configuration changes in git
6. **Separate Environments**: Different configs for dev/staging/prod
7. **Security**: Never commit passwords or sensitive values
