# ⚠️ DEPRECATED - Replaced by AI Dashboard

This task has been deprecated and replaced by the [ai-dashboard](https://github.com/levonk/ai-dashboard) project.

**Migration**: Use the ai-dashboard project for all analytics development.

---
story_id: "07-003"
story_title: "Skills and Tools Analytics Tab"
story_name: "skills-tools-tab"
prd_name: "prd-ai-analytics-pipeline"
prd_file: "internal-docs/deprecated/prd-ai-analytics-pipeline.md"
phase: 7
parallel_id: 3
branch: "feature/current/prd-ai-analytics-pipeline/story-07-003-skills-tools-tab"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["03-003", "04-001"]
parallel_safe: true
modules: ["dashboard", "skills"]
priority: "MUST"
risk_level: "medium"
tags: ["feat", "dashboard"]
due: "2025-03-03"
created_at: "2025-01-20"
updated_at: "2025-01-20"
---

## Summary

Implement the Skills and Tools Analytics tab to show skills invocation analytics, top tools by call count, tool result size analysis, and tool cost attribution.

## Sub-Tasks

- [ ] Design Skills and Tools tab layout
- [ ] Implement skills invocation charts
- [ ] Create top tools by call count visualization
- [ ] Add tool result size analysis
- [ ] Implement tool cost attribution
- [ ] Create tool effectiveness metrics
- [ ] Add skill vs tool comparison
- [ ] Implement tool usage patterns
- [ ] Create tool optimization insights
- [ ] Add responsive layout for skills/tools tab

## Relevant Files

**Project: ~/p/gh/levonk/ai-dashboard**
- `web/tabs/skills-tools.html` - Skills/Tools tab HTML
- `web/tabs/skills-tools.js` - Skills/Tools tab logic
- `web/tabs/skills-tools.css` - Skills/Tools tab styling

**Project: ~/p/gh/levonk/infrahub**
- `shared/active/03-container/ai-analytics/api/skills-tools.py` - Skills/Tools data API
- `tests/test_skills_tools.py` - Skills/Tools tab tests

## Acceptance Criteria

- [ ] Skills invocation charts show usage patterns
- [ ] Top tools visualization highlights frequently used tools
- [ ] Tool result size analysis identifies optimization opportunities
- [ ] Tool cost attribution is accurate
- [ ] Tool effectiveness metrics provide insights
- [ ] Skill vs tool comparison is informative
- [ ] Tool usage patterns reveal optimization opportunities
- [ ] Tool optimization insights are actionable
- [ ] Layout is responsive and user-friendly
- [ ] Data refreshes automatically

## Test Plan

- Unit: Test skills invocation tracking
- Unit: Test tool result size analysis
- Integration: Test skills/tools tab with real data
- Manual: Test tool optimization insights
- Manual: Test responsive layout
- Performance: Test tab loading performance

## Observability

- Skills/Tools tab load times
- Tool analysis performance
- Skills tracking accuracy
- User interaction patterns

## Compliance

- No sensitive tool data exposed
- Tool usage privacy preserved
- Skills data retention policies

## Risks & Mitigations

- Risk: Tool data may be complex to analyze
  - Mitigation: Simplified views with drill-down options
- Risk: Skills tracking may be incomplete
  - Mitigation: Clear documentation of limitations

## Dependencies

- Story 03-003 (Cache and Session Analytics) - for tool context
- Story 04-001 (Dashboard Framework) - for UI framework

## Notes

- Focus on tool optimization insights
- Design for skill effectiveness analysis
- Consider tool categorization for better analytics