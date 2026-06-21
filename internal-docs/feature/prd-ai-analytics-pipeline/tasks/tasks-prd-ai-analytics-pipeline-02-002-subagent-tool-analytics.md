---
story_id: "02-002"
story_title: "Subagent and Tool Analytics"
story_name: "subagent-tool-analytics"
prd_name: "prd-ai-analytics-pipeline"
prd_file: "internal-docs/feature/prd-ai-analytics-pipeline/prd-ai-analytics-pipeline.md"
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

- [ ] Design subagent identification logic
- [ ] Implement subagent type detection from requests
- [ ] Create subagent instance tracking
- [ ] Add tool call extraction and parsing
- [ ] Implement tool usage pattern analysis
- [ ] Create tool result size measurement
- [ ] Add tool cost calculation
- [ ] Implement tool invocation frequency tracking
- [ ] Create subagent performance metrics
- [ ] Add tool/subagent analytics to database
- [ ] Create testing utilities for tool/subagent detection

## Relevant Files

- `analytics/subagent.py` - Subagent identification and tracking
- `analytics/tools.py` - Tool usage analytics
- `collectors/subagent_parser.py` - Subagent detection from requests
- `models/subagent.py` - Subagent data models
- `models/tool.py` - Tool analytics models
- `tests/test_subagent.py` - Subagent analytics tests
- `tests/test_tools.py` - Tool analytics tests

## Acceptance Criteria

- [ ] Subagent types are detected accurately (Claude Code, Codex, Pi, Devin)
- [ ] Subagent instances are tracked for session analysis
- [ ] Tool calls are extracted and parsed correctly
- [ ] Tool usage patterns are analyzed and stored
- [ ] Tool result sizes are measured accurately
- [ ] Tool costs are calculated based on usage
- [ ] Tool invocation frequency is tracked over time
- [ ] Subagent performance metrics are calculated
- [ ] Analytics data is stored efficiently
- [ ] Testing utilities validate detection accuracy

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