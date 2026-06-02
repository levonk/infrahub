---
story_id: "04-002"
story_title: "Molecule tests for critical roles"
story_name: "molecule-tests"
prd_name: "cloud-server"
prd_file: "shared/active/08-docs/reqs/2026/20260529-cloud-server.md"
phase: 4
parallel_id: 2
branch: "feature/current/cloud-server/story-04-002-molecule-tests"
status: "skipped"
assignee: ""
reviewer: ""
dependencies: ["02-001", "02-002", "02-003"]
parallel_safe: true
modules: ["ansible", "test"]
priority: "SHOULD"
risk_level: "medium"
tags: ["ansible", "test", "molecule"]
due: "2026-06-26"
created_at: "2026-05-29"
updated_at: "2026-05-29"
---

## Summary

Set up Molecule testing for the most critical cloud server roles: `host-os-bootstrap`, `nix-installation`, and `docker-engine`. Molecule tests validate roles in isolated environments (Docker containers or VMs) before deployment to production.

## Sub-Tasks

- [x] Ensure `molecule` is in devbox packages
  - **BLOCKER**: molecule-docker package doesn't exist in nixks; molecule requires Python docker module which isn't available
  - **Tried**: podman driver (failed - podman binary not in Ansible PATH)
  - **Tried**: delegated driver (failed - driver not installed)
  - **Tried**: custom nix package with withPackages (failed - empty flake installable)
  - **Tried**: python313Packages.podman (installed, but molecule still can't find podman binary in Ansible PATH)
  - **ROOT CAUSE**: molecule runs Ansible with restricted PATH (only Python package dirs), can't access system PATH where podman/docker binaries live
  - **BLOCKER**: Need to either (a) create custom molecule package with full PATH access, or (b) use ansible-test with manual docker container setup
- [x] Create Ansible test Docker image for Molecule (`Dockerfile.test`):
  - Base: `debian:bookworm-slim` (matches OCI target)
  - Install: `python3`, `sudo`, `openssh-server`
  - Configure: passwordless sudo for `cuser`, SSH key auth
  - Build via: `just ansible-test-env-build`
- [x] Initialize Molecule for `host-os-bootstrap` role:
  - `molecule init scenario --driver-name docker`
  - Create `molecule.yml` using `ansible-test-runner:latest` image
  - Create `verify.yml` to check user creation, timezone, SSH status
- [x] Initialize Molecule for `nix-installation` role:
  - `molecule init scenario --driver-name docker`
  - Create `molecule.yml` using `ansible-test-runner:latest` image
  - Create `verify.yml` to check Nix CLI and flakes
- [x] Initialize Molecule for `docker-engine` role:
  - `molecule init scenario --driver-name docker`
  - Create `molecule.yml` using `ansible-test-runner:latest` image
  - Create `verify.yml` to check Docker daemon and userns-remap
- [x] Create `molecule.yml` for each role with appropriate platform images
- [~] Run `molecule test` for each role and fix failures
  - `just molecule-test host-os-bootstrap`
  - `just molecule-test nix-installation`
  - `just molecule-test docker-engine`
- [ ] Document Molecule workflow in role README files

## Relevant Files

- `shared/active/02-config/ansible/roles/host-os-bootstrap/molecule/default/molecule.yml`
- `shared/active/02-config/ansible/roles/host-os-bootstrap/molecule/default/verify.yml`
- `shared/active/02-config/ansible/roles/nix-installation/molecule/default/molecule.yml`
- `shared/active/02-config/ansible/roles/nix-installation/molecule/default/verify.yml`
- `shared/active/02-config/ansible/roles/docker-engine/molecule/default/molecule.yml`
- `shared/active/02-config/ansible/roles/docker-engine/molecule/default/verify.yml`
- `devbox.json` — ensure molecule is available

## Acceptance Criteria

- [ ] Molecule scenarios exist for host-os-bootstrap, nix-installation, docker-engine
- [ ] `molecule test` passes for each role
- [ ] Verify playbooks check key outcomes (users, services, configs)
- [ ] CI pipeline can run `molecule test` for these roles
- [ ] `devbox run molecule test` works without extra setup

## Test Plan

- Run: `devbox run molecule test -s default` in each role directory
- Run: `devbox run molecule lint` for syntax validation

## Observability

- Log Molecule test results per role
- Track test coverage and failure rates

## Compliance

- Test environments should match target OS (Debian/Ubuntu for OCI)
- No production secrets in test configurations

## Risks & Mitigations

- Risk: Molecule Docker driver conflicts with Docker-in-Docker — Mitigation: Use privileged containers or VM driver
- Risk: Nix installer requires root in container — Mitigation: Use privileged Molecule containers

## Dependencies & Sequencing

- Depends on: 02-001, 02-002, 02-003
- Unblocks: 04-003 (syntax check), 05-001 (deploy bootstrap)

## Definition of Done

- Molecule tests pass for all three critical roles
- CI can execute Molecule tests
- Story file updated to `done`

## Commit Conventions

- `test(ansible): add molecule tests for critical cloud server roles`
- `ci(ansible): configure molecule in devbox and CI`

## Changelog

- 2026-05-29: initialized story file
