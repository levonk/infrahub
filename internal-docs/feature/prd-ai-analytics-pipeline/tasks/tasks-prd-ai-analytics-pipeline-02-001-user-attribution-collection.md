---
story_id: "02-001"
story_title: "User Attribution Collection"
story_name: "user-attribution-collection"
prd_name: "prd-ai-analytics-pipeline"
prd_file: "internal-docs/feature/prd-ai-analytics-pipeline/prd-ai-analytics-pipeline.md"
phase: 2
parallel_id: 1
branch: "feature/current/prd-ai-analytics-pipeline/story-02-001-user-attribution-collection"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["01-002"]
parallel_safe: true
modules: ["collectors", "attribution"]
priority: "MUST"
risk_level: "medium"
tags: ["feat", "attribution"]
due: "2025-01-27"
created_at: "2025-01-20"
updated_at: "2025-01-20"
---

## Summary

Implement user-level attribution collection in the collectors to track which users, machines, and client keys are making AI requests. This enables user-specific analytics and basic privacy controls.

## Sub-Tasks

- [ ] Design user attribution extraction logic
- [ ] Implement user identification from requests
- [ ] Add machine fingerprinting
- [ ] Create client key extraction and validation
- [ ] Implement attribution metadata enrichment
- [ ] Add user/machine/client key lookup or creation
- [ ] Create attribution context for requests
- [ ] Implement privacy controls for user data
- [ ] Add attribution to message queue format
- [ ] Create attribution testing utilities

## Relevant Files

- `collectors/attribution.py` - User attribution logic
- `collectors/fingerprint.py` - Machine fingerprinting
- `collectors/client_keys.py` - Client key handling
- `models/user.py` - User data models
- `tests/test_attribution.py` - Attribution tests

## Acceptance Criteria

- [ ] User identification works reliably from requests
- [ ] Machine fingerprinting is consistent
- [ ] Client keys are extracted and validated
- [ ] Attribution metadata is enriched in requests
- [ ] User/machine/client key records created as needed
- [ ] Privacy controls allow user data anonymization
- [ ] Attribution data flows through message queue
- [ ] Performance impact is minimal (<1ms additional latency)
- [ ] Attribution works across different client types
- [ ] Testing utilities validate attribution accuracy

## Test Plan

- Unit: Test user identification logic
- Unit: Test machine fingerprinting consistency
- Unit: Test client key extraction and validation
- Integration: Test attribution end-to-end flow
- Privacy: Test anonymization and privacy controls
- Performance: Measure attribution latency impact

## Observability

- Attribution success/failure rates
- Unknown user/machine/client key counts
- Privacy control application metrics
- Attribution latency metrics

## Compliance

- User consent for attribution tracking
- Data anonymization capabilities
- Client key security and validation
- Privacy by design principles

## Risks & Mitigations

- Risk: User identification may fail for some requests
  - Mitigation: Fallback to anonymous attribution
- Risk: Machine fingerprinting may not be unique
  - Mitigation: Use multiple fingerprinting methods

## Dependencies

- Story 01-002 (User Data Model) - for database schema

## Notes

- Consider GDPR and privacy implications
- Design for future authentication integration
- Balance attribution granularity with privacy