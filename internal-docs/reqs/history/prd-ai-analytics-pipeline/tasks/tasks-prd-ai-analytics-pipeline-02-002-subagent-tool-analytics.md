# ⚠️ DEPRECATED - Replaced by AI Dashboard

This task has been deprecated and replaced by the [ai-dashboard](https://github.com/levonk/ai-dashboard) project.

**Migration**: Use the ai-dashboard project for all analytics development.

---
story_id: "02-002"
story_title: "Subagent and Tool Analytics"
story_name: "subagent-tool-analytics"
prd_name: "prd-ai-analytics-pipeline"
prd_file: "internal-docs/deprecated/prd-ai-analytics-pipeline.md"
phase: 2
parallel_id: 2
branch: "feature/current/prd-ai-analytics-pipeline/story-02-002-subagent-tool-analytics"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["01-002"]
parallel_safe: true
modules: ["analytics", "subagent"]
priority: "MUST"
risk_level: "medium"
tags: ["feat", "analytics"]
due: "2025-01-27"
created_at: "2025-01-20"
updated_at: "2025-01-20"
---

## Summary

Implement subagent attribution to track which AI agents (Claude Code, Codex, Pi, Devin, etc.) are making requests, along with tool-level analytics to capture tool usage patterns, result sizes, and costs.

## Sub-Tasks

- [x] Design subagent identification logic
- [x] Implement subagent type detection from requests
- [x] Create subagent instance tracking
- [x] Add tool call extraction and parsing
- [x] Implement tool usage pattern analysis
- [x] Create tool result size measurement
- [x] Add tool cost calculation
- [x] Implement tool invocation frequency tracking
- [x] Create subagent performance metrics
- [x] Add tool/subagent analytics to database
- [x] Create testing utilities for tool/subagent detection

## Relevant Files

- `collectors/subagent.py` - Subagent identification and tracking
- `collectors/tools.py` - Tool usage analytics
- `models/subagent.py` - Subagent data models
- `models/tool.py` - Tool analytics models
- `collectors/tests/test_subagent.py` - Subagent analytics tests
- `collectors/tests/test_tools.py` - Tool analytics tests
- `collectors/database.py` - Fixed dataclass field ordering

## Acceptance Criteria

- [x] Subagent types are detected accurately (Claude Code, Codex, Pi, Devin)
- [x] Subagent instances are tracked for session analysis
- [x] Tool calls are extracted and parsed correctly
- [x] Tool usage patterns are analyzed and stored
- [x] Tool result sizes are measured accurately
- [x] Tool costs are calculated based on usage
- [x] Tool invocation frequency is tracked over time
- [x] Subagent performance metrics are calculated
- [x] Analytics data is stored efficiently
- [x] Testing utilities validate detection accuracy

## Test Plan

- Unit: Test subagent type detection
- Unit: Test tool call extraction and parsing
- Unit: Test tool usage pattern analysis
- Integration: Test end-to-end subagent/tool analytics
- Performance: Measure analytics processing overhead
- Accuracy: Validate against known subagent/tool patterns

## Observability

- Subagent detection success/failure rates
- Tool call extraction metrics
- Tool usage pattern metrics
- Subagent performance indicators
- Analytics processing latency

## Compliance

- No sensitive tool data logged
- Tool result size limits enforced
- Subagent identification privacy considerations

## Risks & Mitigations

- Risk: Subagent detection may fail for new agents
  - Mitigation: Extensible detection framework
- Risk: Tool parsing may be complex for different agents
  - Mitigation: Agent-specific parsers with fallbacks

## Dependencies

- Story 01-002 (User Data Model) - for database schema

## Notes

- Design for extensibility to support new AI agents
- Consider tool categorization for better analytics
- Balance detailed tracking with performance