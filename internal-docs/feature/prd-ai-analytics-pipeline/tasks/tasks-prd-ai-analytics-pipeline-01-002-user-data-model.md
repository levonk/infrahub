---
story_id: "01-002"
story_title: "User-Level Data Model"
story_name: "user-data-model"
prd_name: "prd-ai-analytics-pipeline"
prd_file: "internal-docs/feature/prd-ai-analytics-pipeline/prd-ai-analytics-pipeline.md"
phase: 1
parallel_id: 2
branch: "feature/current/prd-ai-analytics-pipeline/story-01-002-user-data-model"
status: "todo"
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

- [ ] Design database schema for request/response events
- [ ] Create user attribution tables (users, machines, client_keys)
- [ ] Design subagent attribution schema
- [ ] Create tool-level analytics tables
- [ ] Design file-level analytics schema
- [ ] Create session data tables
- [ ] Design cache analytics schema
- [ ] Create skills analytics tables
- [ ] Implement derived metrics tables
- [ ] Create time-series aggregation tables
- [ ] Design configuration data tables
- [ ] Implement database migration system
- [ ] Create database initialization scripts
- [ ] Add database indexes for performance
- [ ] Implement data retention and pruning logic

## Relevant Files

**Project: /Users/micro/p/gh/levonk/infrahub**
- `shared/active/03-container/ai-analytics/schema.sql` - Main database schema definition
- `shared/active/03-container/ai-analytics/migrations/` - Database migration files
- `shared/active/03-container/ai-analytics/models/` - ORM models or database access layer
- `shared/active/03-container/ai-analytics/db.py` - Database connection and utilities
- `shared/active/03-container/ai-analytics/init_db.py` - Database initialization script
- `tests/test_schema.py` - Schema validation tests

## Acceptance Criteria

- [ ] Database schema supports all PRD data requirements
- [ ] User attribution properly modeled (user, machine, client key)
- [ ] Subagent tracking tables support multiple agent types
- [ ] Tool analytics capture usage patterns and costs
- [ ] File analytics track access patterns and token usage
- [ ] Session data supports turn-by-turn analysis
- [ ] Cache analytics capture hit/miss ratios and savings
- [ ] Migration system allows schema evolution
- [ ] Performance indexes on frequently queried fields
- [ ] Data retention logic can prune old data

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