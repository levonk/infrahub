---
story_id: "05-001"
story_title: "Deploy bootstrap to OCI host"
story_name: "deploy-bootstrap"
prd_name: "cloud-server"
prd_file: "shared/active/08-docs/reqs/2026/20260529-cloud-server.md"
phase: 5
parallel_id: 1
branch: "feature/current/cloud-server/story-05-001-deploy-bootstrap"
status: "in_progress"
assignee: ""
reviewer: ""
dependencies: ["03-001", "04-001", "04-003"]
parallel_safe: false
modules: ["ansible", "deploy"]
priority: "MUST"
risk_level: "high"
tags: ["ansible", "deploy", "oci"]
due: "2026-07-03"
created_at: "2026-05-29"
updated_at: "2026-05-29"
---

## Summary

Execute the `cloud-server-bootstrap.yml` playbook against the OCI host. This is the first real deployment and must be done carefully with validation at each step. Must be runnable via `devbox run ansible-playbook`.

## Sub-Tasks

- [x] Verify inventory `oci.yml` points to correct host and SSH key
- [x] Verify `cloud_server_ansible_host_ip` is populated
- [x] Run playbook with `--check --diff` first as final validation
- [ ] Execute: `devbox run ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/cloud-server-bootstrap.yml`
- [ ] Monitor output for failures or unexpected changes
- [ ] Validate post-conditions:
  - SSH to `cuser@<host>` works with ed25519 key
  - `nix --version` returns version on host
  - `docker ps` works for `cuser`
  - `zsh` is default shell for `cuser`
  - `timedatectl` shows UTC timezone
- [ ] Add deployment notes to ticket
- [ ] If failures occur: fix root cause, re-run, validate again

## Relevant Files

- `shared/active/02-config/ansible/playbooks/cloud-server-bootstrap.yml`
- `levonk/active/02-config/ansible/inventories/oci.yml`
- `levonk/active/02-config/ansible/group_vars/cloud_servers.yml`
- `shared/active/02-config/ansible/roles/host-os-bootstrap/defaults/main.yml` — Added Red Hat package list
- `shared/active/02-config/ansible/roles/host-os-bootstrap/tasks/main.yml` — Fixed Red Hat package installation

## Acceptance Criteria

- [ ] Playbook executes without fatal errors
- [ ] `cuser` can SSH with ed25519 key
- [ ] Nix CLI is functional
- [ ] Docker daemon is running and accessible
- [ ] zsh is default shell, neovim and devbox are available
- [ ] UTC timezone is set
- [ ] No regressions from previous state

## Test Plan

- Deploy: `devbox run ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/cloud-server-bootstrap.yml`
- Verify SSH: `ssh -i <key> cuser@<host> "echo OK"`
- Verify Nix: `ssh -i <key> cuser@<host> "nix --version"`
- Verify Docker: `ssh -i <key> cuser@<host> "docker ps"`
- Verify Timezone: `ssh -i <key> cuser@<host> "timedatectl | grep zone"`

## Observability

- Capture full Ansible output (use `--verbose` or log to file)
- Record deployment duration and any retry attempts

## Compliance

- No manual workarounds — fix root causes in roles/playbooks
- Document any deviations from expected behavior

## Risks & Mitigations

- Risk: SSH key auth fails on first run — Mitigation: Verify keys are pre-installed via cloud-init or manual bootstrap
- Risk: Package update breaks something — Mitigation: Pin critical package versions in variables

## Dependencies & Sequencing

- Depends on: 03-001 (bootstrap playbook), 04-001 (lint), 04-003 (syntax check)
- Unblocks: 05-002 (deploy VPN layer), 06-001 (validate bootstrap)

## Definition of Done

- Bootstrap deployed and validated on OCI host
- All post-conditions pass
- Story file updated to `done`

## Commit Conventions

- `deploy(ansible): execute cloud-server-bootstrap on OCI`
- `fix(ansible): resolve bootstrap deployment issues`

## Changelog

- 2026-05-29: initialized story file
