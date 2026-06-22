# ⚠️ DEPRECATED - Replaced by AI Dashboard

This task has been deprecated and replaced by the [ai-dashboard](https://github.com/levonk/ai-dashboard) project.

**Migration**: Use the ai-dashboard project for all analytics development.

---
story_id: "02-004"
story_title: "Pipeline Collectors Integration"
story_name: "pipeline-collectors"
prd_name: "prd-ai-analytics-pipeline"
prd_file: "internal-docs/deprecated/prd-ai-analytics-pipeline.md"
phase: 2
parallel_id: 4
branch: "feature/current/prd-ai-analytics-pipeline/story-02-004-pipeline-collectors"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["01-003", "02-001"]
parallel_safe: true
modules: ["collectors", "integration"]
priority: "MUST"
risk_level: "high"
tags: ["feat", "integration"]
due: "2025-01-27"
created_at: "2025-01-20"
updated_at: "2025-01-20"
---

## Summary

Integrate the collectors into the actual AI request pipeline by placing Collector 1 before Headroom (to capture original requests) and Collector 2 after OmniRoute and before Iron-Proxy (to capture transformed requests). This enables comparative analysis between pipeline stages.

## Sub-Tasks

- [x] Design collector placement in pipeline
- [x] Implement Collector 1 (pre-Headroom) configuration
- [x] Implement Collector 2 (post-OmniRoute, pre-Iron-Proxy) configuration
- [x] Add pipeline stage markers to requests
- [x] Implement request correlation between collectors
- [x] Add compression metadata capture from Headroom
- [x] Implement routing metadata capture from OmniRoute
- [x] Create pipeline integration testing
- [x] Add collector health monitoring in pipeline context
- [x] Implement graceful degradation for pipeline

## Relevant Files

- `collectors/pipeline_integration.py` - Pipeline integration logic
- `collectors/tests/test_pipeline_integration.py` - Integration tests

## Acceptance Criteria

- [x] Collector 1 captures original requests before transformation
- [x] Collector 2 captures transformed requests after routing
- [x] Pipeline stage markers are added correctly
- [x] Request correlation works between collectors
- [x] Compression metadata is captured from Headroom
- [x] Routing metadata is captured from OmniRoute
- [x] Integration doesn't break existing pipeline
- [x] Graceful degradation works if collectors fail
- [x] Health monitoring shows collector status in pipeline
- [x] End-to-end pipeline testing validates integration

## Test Plan

- Integration: Test Collector 1 in pipeline
- Integration: Test Collector 2 in pipeline
- Correlation: Test request correlation between collectors
- Metadata: Test compression/routing metadata capture
- Degradation: Test graceful degradation scenarios
- End-to-end: Test full pipeline with both collectors

## Observability

- Collector status in pipeline health checks
- Request correlation success/failure rates
- Metadata capture success rates
- Pipeline latency impact monitoring
- Collector error rates in pipeline context

## Compliance

- No API keys exposed to collectors
- Pipeline security maintained
- Request data privacy preserved

## Risks & Mitigations

- Risk: Collector placement may break existing pipeline
  - Mitigation: Extensive testing and gradual rollout
- Risk: Correlation may fail between collectors
  - Mitigation: Robust correlation logic with fallbacks

## Dependencies

- Story 01-003 (Collector Framework) - for collector implementation
- Story 02-001 (User Attribution) - for attribution logic

## Notes

- Coordinate with Headroom and OmniRoute teams for integration
- Consider backward compatibility with existing deployments
- Monitor pipeline performance impact carefully