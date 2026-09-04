# ⚠️ DEPRECATED - Replaced by AI Dashboard

This task has been deprecated and replaced by the [ai-dashboard](https://github.com/levonk/ai-dashboard) project.

**Migration**: Use the ai-dashboard project for all analytics development.

---
story_id: "03-004"
story_title: "File-Level Analytics"
story_name: "file-analytics"
prd_name: "prd-ai-analytics-pipeline"
prd_file: "internal-docs/deprecated/prd-ai-analytics-pipeline.md"
phase: 3
parallel_id: 4
branch: "feature/current/prd-ai-analytics-pipeline/story-03-004-file-analytics"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["02-002"]
parallel_safe: true
modules: ["analytics", "files"]
priority: "MUST"
risk_level: "medium"
tags: ["feat", "analytics"]
due: "2025-02-03"
created_at: "2025-01-20"
updated_at: "2025-01-20"
---

## Summary

Implement file-level analytics to track file access patterns, touch frequency, file-level token usage, and generate file heatmaps. This helps identify which files are accessed most and their associated costs.

## Sub-Tasks

- [ ] Design file analytics framework
- [ ] Implement file path extraction and normalization
- [ ] Create file touch frequency tracking
- [ ] Add file-level token usage calculation
- [ ] Implement file heatmap generation
- [ ] Create file access pattern analysis
- [ ] Add file cost attribution
- [ ] Implement file category classification
- [ ] Create file comparison features
- [ ] Add file analytics to database

## Relevant Files

- `analytics/files.py` - File-level analytics
- `analytics/heatmaps.py` - File heatmap generation
- `analytics/file_patterns.py` - File access pattern analysis
- `models/file.py` - File analytics models
- `tests/test_files.py` - File analytics tests
- `tests/test_heatmaps.py` - Heatmap generation tests

## Acceptance Criteria

- [ ] File path extraction works for different formats
- [ ] File touch frequency tracking is accurate
- [ ] File-level token usage is calculated correctly
- [ ] File heatmaps are generated effectively
- [ ] File access patterns provide insights
- [ ] File cost attribution works
- [ ] File category classification is useful
- [ ] File comparison features work
- [ ] Analytics data supports dashboard queries
- [ ] Testing utilities validate analytics accuracy

## Test Plan

- Unit: Test file path extraction and normalization
- Unit: Test file touch frequency tracking
- Unit: Test file heatmap generation
- Integration: Test end-to-end file analytics
- Performance: Measure analytics processing overhead
- Accuracy: Validate against known file access patterns

## Observability

- File analytics processing metrics
- File path extraction success rates
- Heatmap generation performance
- File access pattern indicators
- File query performance

## Compliance

- No sensitive file content logged
- File path privacy considerations
- File data retention policies

## Risks & Mitigations

- Risk: File path normalization may be complex
  - Mitigation: Use established path handling libraries
- Risk: File heatmaps may be computationally expensive
  - Mitigation: Caching and incremental updates

## Dependencies

- Story 02-002 (Subagent and Tool Analytics) - for file operation context

## Notes

- Consider different file types (code, config, data)
- Design for project-specific file analytics
- Balance detailed tracking with storage costs