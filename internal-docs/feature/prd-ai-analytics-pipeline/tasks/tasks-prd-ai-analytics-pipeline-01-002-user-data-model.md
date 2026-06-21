---
story_id: "01-002"
story_title: "User-Level Data Model"
story_name: "user-data-model"
prd_name: "prd-ai-analytics-pipeline"
prd_file: "internal-docs/feature/prd-ai-analytics-pipeline/prd-ai-analytics-pipeline.md"
phase: 1
parallel_id: 2
branch: "feature/current/prd-ai-analytics-pipeline/story-01-002-user-data-model"
status: "in-progress"
assignee: ""
reviewer: ""
dependencies: []
parallel_safe: true
modules: ["database", "schema"]
priority: "MUST"
risk_level: "medium"
tags: ["feat", "database"]
due: "2025-01-20"
created_at: "2025-01-20"
updated_at: "2025-01-20"
---

## Summary

Design and implement the SQLite database schema with user-level attribution (user, machine, client key) and support for all analytics dimensions including subagent tracking, tool analytics, file analytics, and session data.

## Sub-Tasks

- [x] Design database schema for request/response events
- [x] Create user attribution tables (users, machines, client_keys)
- [x] Design subagent attribution schema
- [x] Create tool-level analytics tables
- [x] Design file-level analytics schema
- [x] Create session data tables
- [x] Design cache analytics schema
- [x] Create skills analytics tables
- [x] Implement derived metrics tables
- [x] Create time-series aggregation tables
- [x] Design configuration data tables
- [x] Implement database migration system
- [x] Create database initialization scripts
- [x] Add database indexes for performance
- [x] Implement data retention and pruning logic

## Relevant Files

**Project: /Users/micro/p/gh/levonk/infrahub**
- `shared/active/03-container/services/ai-analytics/schema.sql` - Complete database schema definition with all tables, indexes, triggers, and views
- `shared/active/03-container/services/ai-analytics/migrations/001_initial_schema.sql` - Initial schema migration with idempotent execution
- `shared/active/03-container/services/ai-analytics/migrations/migrate.py` - Migration system with version tracking and rollback support
- `shared/active/03-container/services/ai-analytics/init_db.py` - Database initialization script with schema verification
- `shared/active/03-container/services/ai-analytics/data_retention.py` - Data retention and pruning logic with configurable policies

## Acceptance Criteria

- [x] Database schema supports all PRD data requirements
- [x] User attribution properly modeled (user, machine, client key)
- [x] Subagent tracking tables support multiple agent types
- [x] Tool analytics capture usage patterns and costs
- [x] File analytics track access patterns and token usage
- [x] Session data supports turn-by-turn analysis
- [x] Cache analytics capture hit/miss ratios and savings
- [x] Migration system allows schema evolution
- [x] Performance indexes on frequently queried fields
- [x] Data retention logic can prune old data

## Test Plan

- Unit: Test database creation and migration
- Unit: Test CRUD operations on all tables
- Unit: Test data retention and pruning logic
- Integration: Test database connection and queries
- Performance: Verify query performance with indexes

## Observability

- Logging for database operations
- Metrics for query performance
- Health check endpoint for database status

## Compliance

- No PII stored without explicit user consent
- Data retention policies enforced
- Secure storage of sensitive configuration data

## Risks & Mitigations

- Risk: Schema changes may break existing data
  - Mitigation: Robust migration system with rollback capability
- Risk: Database performance may degrade with large datasets
  - Mitigation: Proper indexing and query optimization from start

## Dependencies

- None (can be developed in parallel with 01-001)

## Notes

- Schema should be extensible for future enterprise features
- Consider data partitioning strategies for future scaling
- Document all schema decisions and relationships