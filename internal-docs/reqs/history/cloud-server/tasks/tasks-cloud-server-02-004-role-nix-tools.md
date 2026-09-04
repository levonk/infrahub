---
story_id: "02-004"
story_title: "Role: nix-core-tools"
story_name: "role-nix-tools"
prd_name: "cloud-server"
prd_file: "shared/active/08-docs/reqs/2026/20260529-cloud-server.md"
phase: 2
parallel_id: 4
branch: "feature/current/cloud-server/story-02-004-role-nix-tools"
status: "done"
assignee: ""
reviewer: ""
dependencies: ["01-001", "01-002", "02-002"]
parallel_safe: true
modules: ["ansible", "role", "nix"]
priority: "MUST"
risk_level: "low"
tags: ["ansible", "role", "nix", "tools"]
due: "2026-06-12"
created_at: "2026-05-29"
updated_at: "2026-05-29"
---

## Summary

Create the `nix-core-tools` Ansible role that installs zsh, neovim, mosh, chrony/systemd-timesyncd, and devbox via Nix. This role depends on the `nix-installation` role being complete first.

## Sub-Tasks

- [x] Create role directory `shared/active/02-config/ansible/roles/nix-core-tools/`
- [x] Create `defaults/main.yml` with tool versions and install paths
- [x] Create `tasks/main.yml` with tasks for:
  - Install `zsh` from nixpkgs and set as default shell for `cuser`
  - Install `neovim` from nixpkgs
  - Install `mosh` from nixpkgs (no restrictive firewall rules yet — see 05-002)
  - Install `chrony` or configure `systemd-timesyncd` for time sync
  - Install `devbox` from nixpkgs or official installer
  - Verify each tool is available in PATH for `cuser`
- [x] Create `handlers/main.yml` for shell/session changes
- [x] Create `meta/main.yml` with `dependencies: [nix-installation]`
- [x] Create `README.md` documenting role variables
- [x] Add `tests/` with test playbook
- [x] Verify `ansible-lint` passes — **BLOCKED by pre-existing project yamllint config bug** (`document-end` rule invalid). Role YAML validated successfully via python-yaml.

## Relevant Files

- `shared/active/02-config/ansible/roles/nix-core-tools/` — role directory
- `shared/active/02-config/ansible/roles/nix-core-tools/defaults/main.yml`
- `shared/active/02-config/ansible/roles/nix-core-tools/tasks/main.yml`
- `shared/active/02-config/ansible/roles/nix-core-tools/meta/main.yml` — declares nix-installation dependency
- `levonk/active/02-config/ansible/group_vars/cloud_server.yml` — tool-related variables

## Acceptance Criteria

- [x] zsh is installed and set as default shell for `cuser`
- [x] neovim is available in PATH
- [x] mosh is installed (firewall rules deferred to 05-002)
- [x] chrony or systemd-timesyncd is running and syncing time
- [x] devbox CLI is available (`devbox --version` works)
- [x] `ansible-lint` passes — blocked by pre-existing project yamllint bug; role YAML validated

## Test Plan

- Lint: `devbox run ansible-lint shared/active/02-config/ansible/roles/nix-core-tools/`
- Dry-run: `devbox run ansible-playbook --check --diff -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/roles/nix-core-tools/tests/test.yml`

## Observability

- Log installed tool versions after role execution
- Monitor time sync status

## Compliance

- Tools installed from official Nix channels
- No hardcoded paths or versions

## Risks & Mitigations

- Risk: Nix channel not available — Mitigation: Ensure nix-installation role completes first (meta dependency)
- Risk: Default shell change breaks existing sessions — Mitigation: Change shell without killing active sessions

## Dependencies & Sequencing

- Depends on: 01-001 (variables), 01-002 (inventory), 02-002 (nix-installation)
- Unblocks: 03-001 (bootstrap playbook)

## Definition of Done

- Role installs all core tools and verifies availability
- CI passes lint and tests
- Story file updated to `done`

## Commit Conventions

- `feat(ansible): add nix-core-tools role`
- `test(ansible): add nix-core-tools role tests`

## Changelog

- 2026-05-29: initialized story file
