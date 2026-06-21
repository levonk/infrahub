---
story_id: "07-002"
story_title: "Rule-Based Tips Engine"
story_name: "tips-engine"
prd_name: "prd-ai-analytics-pipeline"
prd_file: "internal-docs/feature/prd-ai-analytics-pipeline/prd-ai-analytics-pipeline.md"
phase: 7
parallel_id: 2
branch: "feature/current/prd-ai-analytics-pipeline/story-07-002-tips-engine"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["03-003"]
parallel_safe: true
modules: ["analytics", "tips"]
priority: "MUST"
risk_level: "medium"
tags: ["feat", "analytics"]
due: "2025-03-03"
created_at: "2025-01-20"
updated_at: "2025-01-20"
---

## Summary

Implement a rule-based tips engine to provide suggestions for cost optimization, wasteful pattern detection (repeated file reads, oversized tool results), and actionable recommendations for reducing token usage.

## Sub-Tasks

- [ ] Design tips engine architecture
- [ ] Implement rule definition framework
- [ ] Create cost optimization rules
- [ ] Add wasteful pattern detection rules
- [ ] Implement repeated file read detection
- [ ] Create oversized tool result detection
- [ ] Add low cache-hit rate detection
- [ ] Implement tip generation and prioritization
- [ ] Create tip dismissal and feedback
- [ ] Add tip performance tracking

## Relevant Files

- `analytics/tips.py` - Tips engine framework
- `analytics/rules.py` - Rule definitions
- `analytics/patterns.py` - Pattern detection
- `models/tip.py` - Tip data models
- `tests/test_tips.py` - Tips engine tests
- `tests/test_patterns.py` - Pattern detection tests

## Acceptance Criteria

- [ ] Tips engine generates actionable recommendations
- [ ] Cost optimization rules identify savings opportunities
- [ ] Wasteful pattern detection works accurately
- [ ] Repeated file read detection is reliable
- [ ] Oversized tool result detection provides insights
- [ ] Low cache-hit rate detection suggests improvements
- [ ] Tip prioritization surfaces most important issues
- [ ] Tip dismissal and feedback work correctly
- [ ] Tip performance tracking measures effectiveness
- [ ] Rules are extensible for new patterns

## Test Plan

- Unit: Test each rule type
- Unit: Test pattern detection accuracy
- Integration: Test tips engine with real data
- Manual: Test tip generation and display
- Performance: Test tips engine performance
- User: Test tip feedback loop

## Observability

- Tips engine performance metrics
- Rule trigger rates
- Tip dismissal rates
- User feedback on tips

## Compliance

- Tips don't expose sensitive data
- Pattern detection privacy preserved
- Tip data retention policies

## Risks & Mitigations

- Risk: Tips may be noisy or irrelevant
  - Mitigation: User feedback and tip prioritization
- Risk: Pattern detection may be complex
  - Mitigation: Start with simple, high-value patterns

## Dependencies

- Story 03-003 (Cache and Session Analytics) - for pattern data

## Notes

- Focus on high-impact, actionable tips
- Design for learning from user feedback
- Consider tip personalization over time