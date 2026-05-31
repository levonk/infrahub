---
prd_name: "cloud-server"
prd_file: "shared/active/08-docs/reqs/2026/20260529-cloud-server.md"
created_at: "2026-05-29"
updated_at: "2026-05-29"
---

# Cloud Server — Task Index

## Overview

Implementation of the cloud server requirements from `shared/active/08-docs/reqs/2026/20260529-cloud-server.md`, following the infrahub/ansible lifecycle: variables → roles → playbooks → lint/tests → deploy → validate.

All development and deployment commands must work through `devbox run ...` per ADR-20260131001.

**Build Tooling**: NX (`nx.json` at root), just (`justfile` at root), devbox (`devbox.json` at root) per ADR-20260419001.

**Docker Containers**: Ansible test environments use Docker containers (Molecule driver) via `just ansible-test-env-*` commands.

**Packer VM Images**: OCI base VM image is created with Packer via `just packer-build` / `devbox run packer-build`.

---

## Phase 01 — Ansible Variables & Inventory

| Story ID | Story Title | Branch | Status | Dependencies | Parallel-safe | Modules |
| -------- | ----------- | ------ | ------ | ------------ | ------------- | ------- |
| 01-001 | Cloud Server Variable Schema (group_vars) | feature/current/cloud-server/story-01-001-group-vars | [x] Done | None | true | ansible, variables |
| 01-002 | OCI Host Inventory & host_vars (incl. Packer base image) | feature/current/cloud-server/story-01-002-oci-inventory | [x] Done | None | true | ansible, inventory, packer |

## Phase 02 — Galaxy Role Development

| Story ID | Story Title | Branch | Status | Dependencies | Parallel-safe | Modules |
| -------- | ----------- | ------ | ------ | ------------ | ------------- | ------- |
| 02-001 | Role: host-os-bootstrap | feature/current/cloud-server/story-02-001-role-os-bootstrap | [x] Done | 01-001, 01-002 | true | ansible, role |
| 02-002 | Role: nix-installation | feature/current/cloud-server/story-02-002-role-nix | [x] Done | 01-001, 01-002 | true | ansible, role, nix |
| 02-003 | Role: docker-engine | feature/current/cloud-server/story-02-003-role-docker | [x] Done | 01-001, 01-002 | true | ansible, role, docker |
| 02-004 | Role: nix-core-tools | feature/current/cloud-server/story-02-004-role-nix-tools | [x] Done | 01-001, 01-002 | true | ansible, role, nix |
| 02-005 | Role: tailscale-vpn | feature/current/cloud-server/story-02-005-role-tailscale | [~] In-Progress | 01-001, 01-002 | true | ansible, role, vpn |
| 02-006 | Role: netbird-client | feature/current/cloud-server/story-02-006-role-netbird-client | [x] Done | 01-001, 01-002 | true | ansible, role, vpn |
| 02-007 | Role: host-firewall | feature/current/cloud-server/story-02-007-role-firewall | [x] Done | 01-001, 01-002 | true | ansible, role, security |
| 02-008 | Role: ssh-hardening | feature/current/cloud-server/story-02-008-role-ssh | [x] Done | 01-001, 01-002 | true | ansible, role, security |
| 02-009 | Role: fail2ban | feature/current/cloud-server/story-02-009-role-fail2ban | [x] Done | 01-001, 01-002 | true | ansible, role, security |
| 02-010 | Role: netbird-control-plane | feature/current/cloud-server/story-02-010-role-netbird-cp | [~] In-Progress | 01-001, 01-002 | true | ansible, role, vpn |
| 02-011 | Role: dns-stack | feature/current/cloud-server/story-02-011-role-dns | [x] Done | 01-001, 01-002 | true | ansible, role, dns |
| 02-012 | Role: proxy-stack | feature/current/cloud-server/story-02-012-role-proxy | [x] Done | 01-001, 01-002 | true | ansible, role, proxy |
| 02-013 | Role: sso-service | feature/current/cloud-server/story-02-013-role-sso | [x] Done | 01-001, 01-002 | true | ansible, role, security |
| 02-014 | Role: kvm-hypervisor | feature/current/cloud-server/story-02-014-role-kvm | [x] Done | 01-001, 01-002 | true | ansible, role, vm |

## Phase 03 — Shared Playbooks

| Story ID | Story Title | Branch | Status | Dependencies | Parallel-safe | Modules |
| -------- | ----------- | ------ | ------ | ------------ | ------------- | ------- |
| 03-001 | Playbook: cloud-server-bootstrap.yml | feature/current/cloud-server/story-03-001-pb-bootstrap | [~] In-Progress | 02-001, 02-002, 02-003, 02-004 | true | ansible, playbook |
| 03-002 | Playbook: cloud-server-vpn.yml | feature/current/cloud-server/story-03-002-pb-vpn | [ ] Todo | 02-005, 02-006, 02-007, 02-008, 02-009 | true | ansible, playbook |
| 03-003 | Playbook: cloud-server-infra.yml | feature/current/cloud-server/story-03-003-pb-infra | [ ] Todo | 02-010, 02-011, 02-012, 02-013 | true | ansible, playbook |
| 03-004 | Playbook: cloud-server-vms.yml | feature/current/cloud-server/story-03-004-pb-vms | [ ] Todo | 02-014 | true | ansible, playbook |
| 03-005 | Site Playbook: cloud-server-site.yml | feature/current/cloud-server/story-03-005-pb-site | [ ] Todo | 03-001, 03-002, 03-003, 03-004 | true | ansible, playbook |

## Phase 04 — Lint & Test

| Story ID | Story Title | Branch | Status | Dependencies | Parallel-safe | Modules |
| -------- | ----------- | ------ | ------ | ------------ | ------------- | ------- |
| 04-001 | ansible-lint configuration & role linting | feature/current/cloud-server/story-04-001-ansible-lint | [ ] Todo | 02-001..02-014 | true | ansible, lint |
| 04-002 | Molecule tests for critical roles (Docker-backed) | feature/current/cloud-server/story-04-002-molecule-tests | [ ] Todo | 02-001, 02-002, 02-003 | true | ansible, test, docker |
| 04-003 | Playbook syntax check & dry-run | feature/current/cloud-server/story-04-003-syntax-check | [ ] Todo | 03-005 | true | ansible, test |

## Phase 05 — Deploy to OCI

| Story ID | Story Title | Branch | Status | Dependencies | Parallel-safe | Modules |
| -------- | ----------- | ------ | ------ | ------------ | ------------- | ------- |
| 05-001 | Deploy bootstrap to OCI host | feature/current/cloud-server/story-05-001-deploy-bootstrap | [ ] Todo | 03-001, 04-001, 04-003 | false | ansible, deploy |
| 05-002 | Deploy VPN layer to OCI host | feature/current/cloud-server/story-05-002-deploy-vpn | [ ] Todo | 03-002, 05-001 | false | ansible, deploy |
| 05-003 | Deploy infrastructure services to OCI | feature/current/cloud-server/story-05-003-deploy-infra | [ ] Todo | 03-003, 05-002 | false | ansible, deploy |
| 05-004 | Deploy VM layer to OCI | feature/current/cloud-server/story-05-004-deploy-vms | [ ] Todo | 03-004, 05-003 | false | ansible, deploy |

## Phase 06 — Validation & Final Testing

| Story ID | Story Title | Branch | Status | Dependencies | Parallel-safe | Modules |
| -------- | ----------- | ------ | ------ | ------------ | ------------- | ------- |
| 06-001 | Validate host bootstrap (SSH, Nix, Docker) | feature/current/cloud-server/story-06-001-validate-bootstrap | [ ] Todo | 05-001 | true | test, validation |
| 06-002 | Validate VPN mesh connectivity | feature/current/cloud-server/story-06-002-validate-vpn | [ ] Todo | 05-002 | true | test, validation |
| 06-003 | Validate infrastructure services | feature/current/cloud-server/story-06-003-validate-infra | [ ] Todo | 05-003 | true | test, validation |
| 06-004 | Validate VM workloads & routing | feature/current/cloud-server/story-06-004-validate-vms | [ ] Todo | 05-004 | true | test, validation |
| 06-005 | Security hardening & final audit | feature/current/cloud-server/story-06-005-final-audit | [ ] Todo | 06-001..06-004 | true | security, audit |

---

## Tooling Quick Reference

| Command | Purpose | Phase |
| ------- | ------- | ----- |
| `devbox run packer-build` | Build OCI base VM image | 01 |
| `devbox run packer-validate` | Validate Packer config | 01 |
| `devbox run ansible-lint` | Lint all roles & playbooks | 04 |
| `devbox run ansible-syntax` | Check playbook syntax | 04 |
| `devbox run ansible-test` | Run Molecule tests (Docker) | 04 |
| `just molecule-test <role>` | Test specific role | 04 |
| `devbox run ansible-deploy-bootstrap` | Deploy bootstrap to OCI | 05 |
| `devbox run ansible-validate-bootstrap` | Validate bootstrap | 06 |
| `nx run infrahub-ansible:lint` | NX lint target | 04 |
| `nx run infrahub-ansible:deploy-bootstrap` | NX deploy target | 05 |
| `nx graph` | View task dependency graph | all |
