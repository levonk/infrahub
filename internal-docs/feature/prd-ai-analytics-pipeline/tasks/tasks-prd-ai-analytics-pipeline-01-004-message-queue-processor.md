---
story_id: "01-004"
story_title: "Message Queue and Basic Processor"
story_name: "message-queue-processor"
prd_name: "prd-ai-analytics-pipeline"
prd_file: "internal-docs/feature/prd-ai-analytics-pipeline/prd-ai-analytics-pipeline.md"
phase: 1
parallel_id: 4
branch: "feature/current/prd-ai-analytics-pipeline/story-01-004-message-queue-processor"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["01-003"]
parallel_safe: true
modules: ["queue", "processor"]
priority: "MUST"
risk_level: "medium"
tags: ["feat", "queue"]
due: "2025-01-20"
created_at: "2025-01-20"
updated_at: "2025-01-20"
---

## Summary

Implement Redis-based message queue and background processor for asynchronous analytics processing. This enables the hot path (request forwarding) to remain fast while heavy analytics processing happens asynchronously.

## Sub-Tasks

- [x] Design message queue architecture
- [x] Implement Redis connection management
- [x] Create message serialization/deserialization
- [x] Implement queue producer (collector integration)
- [x] Create background processor consumer
- [x] Add message retry and error handling
- [x] Implement queue monitoring and metrics
- [x] Create processor worker pool
- [x] Add graceful shutdown handling
- [x] Implement queue depth monitoring
- [x] Create dead letter queue for failed messages
- [x] Add queue configuration and tuning

## Relevant Files

**Project: /Users/micro/p/gh/levonk/infrahub**
- `shared/active/03-container/ai-analytics/queue/redis_client.py` - Redis connection and utilities
- `shared/active/03-container/ai-analytics/queue/producer.py` - Message queue producer
- `shared/active/03-container/ai-analytics/queue/consumer.py` - Message queue consumer
- `shared/active/03-container/ai-analytics/processor/worker.py` - Background processor worker
- `shared/active/03-container/ai-analytics/processor/pool.py` - Worker pool management
- `shared/active/03-container/ai-analytics/queue/config.py` - Queue configuration
- `shared/active/03-container/ai-analytics/queue/metrics.py` - Queue monitoring metrics
- `shared/active/03-container/ai-analytics/queue/errors.py` - Queue error handling
- `tests/test_queue.py` - Queue functionality tests
- `tests/test_processor.py` - Processor tests

## Acceptance Criteria

- [x] Redis connection is reliable and handles reconnection
- [x] Message serialization preserves all analytics data
- [x] Producer can enqueue messages without blocking
- [x] Consumer processes messages asynchronously
- [x] Failed messages are retried with backoff
- [x] Dead letter queue captures permanently failed messages
- [x] Queue depth is monitored and alerted
- [x] Graceful shutdown processes in-flight messages
- [x] Worker pool can scale based on load
- [x] Configuration allows tuning for different workloads

## Test Plan

- Unit: Test Redis connection and reconnection
- Unit: Test message serialization/deserialization
- Unit: Test producer/consumer functionality
- Integration: Test end-to-end message flow
- Performance: Test queue throughput under load
- Error: Test retry logic and dead letter queue

## Observability

- Queue depth metrics
- Message processing rates
- Error rates and retry counts
- Worker pool utilization
- Redis connection status

## Compliance

- No sensitive data in queue messages (use references)
- Message retention policies enforced
- Queue access controlled and authenticated

## Risks & Mitigations

- Risk: Redis failure may cause data loss
  - Mitigation: Implement persistence and backup strategies
- Risk: Queue backlog may cause processing delays
  - Mitigation: Monitor queue depth and scale workers

## Dependencies

- Story 01-003 (Collector Framework) - for message format

## Notes

- Use Redis Streams for reliability and ordering
- Design for horizontal scaling of consumers
- Consider message priority for important analytics