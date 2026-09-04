---
story_id: "04-001"
story_title: "Test: ansible syntax, lint, check mode, project-lint"
story_name: "validation"
prd_name: "add-control-center-dashboard"
prd_file: "internal-docs/feature/todo/add-control-center-dashboard/feat-20260830-control-center-dashboard.md"
phase: 4
parallel_id: 1
branch: "feature/current/add-control-center-dashboard/story-04-001-validation"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["03-001"]
parallel_safe: false
modules: []
priority: "MUST"
risk_level: "low"
tags: ["validation", "ansible-lint", "project-lint", "testing"]
due: "2026-08-30"
created_at: "2026-08-30"
updated_at: "2026-08-30"
---

## Summary

Run all validation gates: ansible syntax check, ansible-lint, check mode, project-lint on all new/modified files.

## Current State

- All prerequisite stories (01-001 through 03-001) are complete
- New files exist: infra variables, build script, Ansible role, Traefik templates, DNS entries, playbooks, just recipes, service catalog entry
- Validation gates have not yet been run against the complete changeset

## Scope

- Run ansible syntax check across all new/modified playbooks and roles
- Run ansible-lint across all new/modified files
- Run check mode (dry run) for the deploy playbook
- Run project-lint on all new files
- Fix any violations found

## Sub-Tasks

- [ ] Run `just ansible-syntax`
- [ ] Run `just ansible-lint`
- [ ] Run `just ansible-deploy-control-center --check` (dry run)
- [ ] Run project-lint on all new files
- [ ] Fix any violations (use `# project-lint: disable=...` only for genuine non-operational constants)

## Relevant Files

- All new/modified files from stories 01-001 through 03-001
- `justfile` — validation recipes
- project-lint configuration

## Acceptance Criteria

- Given all new files, When `just ansible-syntax` runs, Then it exits 0
- Given all new files, When `just ansible-lint` runs, Then it exits 0 with no new violations
- Given the deploy playbook, When `just ansible-deploy-control-center --check` runs, Then it exits 0
- Given all new files, When project-lint runs, Then it exits 0
- Verify: All commands exit 0

## Test Plan

- `just ansible-syntax` exits 0
- `just ansible-lint` exits 0
- `just ansible-deploy-control-center --check` exits 0
- project-lint on all new files exits 0

## Observability

- Validation command outputs are recorded for audit
- Any violations are documented with their resolution

## Compliance

- project-lint enforces no magic numbers — use `# project-lint: disable=...` only for genuine non-operational constants
- ansible-lint must pass with no new violations
- All infrastructure values use `infra_` naming convention

## Risks & Mitigations

- **ansible-lint violations**: Fix the underlying issue; do not disable rules unless justified
- **project-lint violations**: Use disable comments only for genuine non-operational constants (e.g., healthcheck retry counts that are config, not magic numbers)
- **Check mode failures**: Investigate variable resolution issues; ensure all `infra_*` vars are defined

## Dependencies & Sequencing

- **Dependencies**: 03-001 (all playbooks, roles, and configs must exist)
- **Dependants**: 05-001 (deploy-verify needs validation to pass first)
- **Parallel-safe**: false (validation is a gate before deployment)

## Definition of Done

- All validation commands pass with exit 0
- No new ansible-lint violations
- No project-lint violations (or justified disable comments)

## STOP Conditions

- project-lint violations cannot be resolved with legitimate disable comments
- ansible-lint violations cannot be resolved
- Check mode reveals missing variables that cannot be resolved

## Maintenance Notes

- Validation gates should be re-run after any future changes to the control-center stack
- Disable comments must be reviewed periodically to ensure they remain justified

## Commit Conventions

- Commit subject: `test(validation): pass all validation gates for control-center`
- Body: list validation commands run and their results

## Changelog

- 2026-08-30: Story created
