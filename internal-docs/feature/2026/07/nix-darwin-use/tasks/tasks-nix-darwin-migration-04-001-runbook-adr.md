---
story_id: "04-001"
story_title: "Local validation runbook + ADR"
story_name: "runbook-adr"
prd_name: "nix-darwin-migration"
prd_file: "internal-docs/feature/2026/07/nix-darwin-use/feat-202607060157-nix-darwin-migration.md"
phase: 4
parallel_id: 1
branch: "feature/current/nix-darwin-migration/story-04-001-runbook-adr"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["03-001"]
parallel_safe: false
modules: ["infrahub/shared/active/08-docs/", "infrahub/internal-docs/adr/"]
priority: "SHOULD"
risk_level: "low"
tags: ["docs", "runbook", "adr"]
due: "2026-07-27"
created_at: "2026-07-06"
updated_at: "2026-07-06"
---

## Summary

Write the local validation runbook (`nix-darwin-local-validation.md`) documenting how to run `darwin-rebuild switch` directly on a Mac for de-risking, and an ADR recording the architectural decision to make infrahub the single source of truth for macOS system config via nix-darwin, including the user-level-vs-system-level defaults split and the casks-vs-nix-packages principle.

## Current State

- **Relevant files and their roles:**
  - `shared/active/08-docs/runbooks/` — directory for operational runbooks. New file goes here.
  - `internal-docs/adr/2026/07/` — ADR directory for July 2026. New ADR goes here.
  - `internal-docs/feature/2026/07/nix-darwin-use/feat-202607060157-nix-darwin-migration.md` — the PRD. Referenced by the ADR.
- **Existing code excerpts:**
  - ADR naming convention: `adr-YYYYMMDDHHmm-{slug}.md` (from naming-convention-date-embedded.md)
  - Runbook format: no strict template, but should include: prerequisites, commands, expected output, rollback, troubleshooting
- **Repository conventions:**
  - ADRs go in `internal-docs/adr/YYYY/MM/` with date-embedded filename
  - Runbooks go in `shared/active/08-docs/runbooks/`
  - Cross-reference related docs with full paths
- **Build/test/lint commands:**
  | Purpose | Command | Expected Result |
  |---------|---------|-----------------|
  | Runbook exists | `ls shared/active/08-docs/runbooks/nix-darwin-local-validation.md` | exists |
  | ADR exists | `ls internal-docs/adr/2026/07/adr-*nix-darwin*.md` | exists |
  | Runbook referenced | `rg "nix-darwin-local-validation" shared/active/02-config/ansible/playbooks/configure-macos-host.yml` | found (header comment) |

## Scope

**In scope:**
- Create `shared/active/08-docs/runbooks/nix-darwin-local-validation.md` (FR-14)
- Create `internal-docs/adr/2026/07/adr-<timestamp>-nix-darwin-migration.md`
- Add a header comment to `configure-macos-host.yml` referencing the runbook

**Out of scope:**
- Any code changes (playbooks, flake, scripts)
- Any Ansible or Nix changes

## Sub-Tasks

- [ ] Task 1 — Create local validation runbook (FR-14)
  Create `shared/active/08-docs/runbooks/nix-darwin-local-validation.md` with sections:
  - **Prerequisites**: Nix installed (multi-user daemon), the darwin flake at `shared/active/02-config/nix/darwin/`
  - **Local apply**: `nix run nix-darwin -- switch --flake ./shared/active/02-config/nix/darwin#lzkmbp2016`
  - **Expected output**: "building the system configuration...", "activating the configuration...", "reloading service..." etc.
  - **Verification**: `defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates` → `0`; `defaults read com.apple.SubmitDiagInfo AutoSubmit` → `0`; `brew list --cask` → no fleet casks
  - **Idempotency**: re-run → "this configuration is already active" or no diff
  - **Rollback**: `darwin-rebuild rollback` — restores previous generation; `darwin-rebuild generations` to list available generations
  - **Troubleshooting**: common errors (unsupported `system.defaults` key, homebrew cask removal, auser password clobber)
  **Verify**: `ls shared/active/08-docs/runbooks/nix-darwin-local-validation.md` → exists; `rg "darwin-rebuild rollback" shared/active/08-docs/runbooks/nix-darwin-local-validation.md` → found
  **Likely failure**: runbook directory doesn't exist — **cause**: `shared/active/08-docs/runbooks/` not created yet — **fallback**: `mkdir -p shared/active/08-docs/runbooks/`

- [ ] Task 2 — Create ADR
  Generate timestamp: `date +%Y%m%d%H%M` → use for filename.
  Create `internal-docs/adr/2026/07/adr-<timestamp>-nix-darwin-migration.md` with sections:
  - **Status**: Accepted
  - **Context**: macOS system config was split across Ansible (bootstrap playbook), a packages-only Nix flake, and a chezmoi Python script (osx-settings.py) with ~170 settings and 11 sudo prompts. levonk-nix-config had darwin modules that were never deployed.
  - **Decision**: Migrate to nix-darwin in infrahub as the single source of truth for macOS **system-level** config. Three-layer split: (1) nix-darwin for system defaults/privacy/homebrew/nix settings, (2) Ansible for sudo-requiring non-defaults (pmset, chflags), (3) chezmoi for user-level defaults (~130 settings). No home-manager. Fleet apps via Nix packages, not casks. OS auto-updates OFF (OpenCore on lzkmbp2016).
  - **Consequences**: Reduced sudo prompts (11 → 0 for chezmoi, 1 for Ansible). Declarative system config. User-level settings stay in chezmoi (correct layer). levonk-nix-config darwin retired.
  - **Alternatives considered**: (a) home-manager for everything — rejected (user doesn't want it, chezmoi owns home). (b) Migrate all osx-settings.py to nix-darwin — rejected (user-level defaults don't apply reliably via system.defaults). (c) Keep imperative Ansible — rejected (not declarative, sudo prompts).
  **Verify**: `ls internal-docs/adr/2026/07/adr-*nix-darwin*.md` → exists; `rg "three-layer" internal-docs/adr/2026/07/adr-*nix-darwin*.md` → found
  **Likely failure**: ADR directory doesn't exist — **cause**: `internal-docs/adr/2026/07/` not created — **fallback**: `mkdir -p internal-docs/adr/2026/07/`

- [ ] Task 3 — Reference runbook from configure playbook
  Add a header comment to `shared/active/02-config/ansible/playbooks/configure-macos-host.yml`:
  ```yaml
  # Runbook for local validation: shared/active/08-docs/runbooks/nix-darwin-local-validation.md
  # PRD: internal-docs/feature/2026/07/nix-darwin-use/feat-202607060157-nix-darwin-migration.md
  ```
  **Verify**: `rg "nix-darwin-local-validation" shared/active/02-config/ansible/playbooks/configure-macos-host.yml` → found
  **Likely failure**: configure playbook doesn't exist yet — **cause**: story 03-001 not complete — **fallback**: this story depends on 03-001, so it should exist

## Relevant Files

- `shared/active/08-docs/runbooks/nix-darwin-local-validation.md` — new runbook
- `internal-docs/adr/2026/07/adr-<timestamp>-nix-darwin-migration.md` — new ADR
- `shared/active/02-config/ansible/playbooks/configure-macos-host.yml` — add header comment

## Acceptance Criteria

- [ ] `ls shared/active/08-docs/runbooks/nix-darwin-local-validation.md` exists
- [ ] `rg "darwin-rebuild rollback" shared/active/08-docs/runbooks/nix-darwin-local-validation.md` finds rollback instructions
- [ ] `ls internal-docs/adr/2026/07/adr-*nix-darwin*.md` exists
- [ ] `rg "three-layer" internal-docs/adr/2026/07/adr-*nix-darwin*.md` finds the layer split decision
- [ ] `rg "nix-darwin-local-validation" shared/active/02-config/ansible/playbooks/configure-macos-host.yml` finds the reference

## Test Plan

- Manual: follow the runbook on lzkmbp2016 — does `darwin-rebuild switch` work? Does `darwin-rebuild rollback` work?
- `rg` checks per Acceptance Criteria

## Observability

- N/A (documentation)

## Compliance

- N/A

## Risks & Mitigations

- Risk: runbook commands are wrong because the flake changed since 01-002 — Mitigation: verify commands against the actual flake structure before writing
- Risk: ADR doesn't capture a key decision — Mitigation: reference the PRD's adversarial review section for the full decision history

## Failure Modes & Decision Forks

- **Failure mode**: runbook directory doesn't exist — **cause**: `shared/active/08-docs/runbooks/` not created — **fallback**: `mkdir -p`
- **Failure mode**: ADR directory doesn't exist — **cause**: `internal-docs/adr/2026/07/` not created — **fallback**: `mkdir -p`

## Dependencies & Sequencing

- Depends on:
  - story-03-001-playbook-rewrite (configure playbook exists to reference)
- Unblocks: None (terminal story)

## Definition of Done

- [ ] Runbook created with prerequisites, commands, expected output, rollback, troubleshooting
- [ ] ADR created with status, context, decision, consequences, alternatives
- [ ] Configure playbook references the runbook
- [ ] No code files modified (only docs + one comment line in playbook)

## STOP Conditions

Stop and report if:
- The configure playbook doesn't exist (03-001 not complete)
- The runbook commands don't match the actual flake structure

### Decision Forks (Contingency Paths)
- If `shared/active/08-docs/runbooks/` doesn't exist → `mkdir -p` to create it
- If the ADR format doesn't match existing ADRs → check `internal-docs/adr/` for existing examples and match their structure

## Maintenance Notes

- The runbook should be updated if the flake path or host names change.
- The ADR is immutable once accepted — if the decision changes, create a superseding ADR.
- Reviewers: confirm runbook commands work, ADR captures the three-layer split and casks-vs-nix principle.

## Commit Conventions

- `docs(runbook): add nix-darwin local validation runbook`
- `docs(adr): record nix-darwin migration decision`

## Changelog

- 2026-07-06: initialized story file
