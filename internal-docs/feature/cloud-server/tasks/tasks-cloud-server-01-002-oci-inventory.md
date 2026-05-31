---
story_id: "01-002"
story_title: "OCI Host Inventory & host_vars"
story_name: "oci-inventory"
prd_name: "cloud-server"
prd_file: "shared/active/08-docs/reqs/2026/20260529-cloud-server.md"
phase: 1
parallel_id: 2
branch: "feature/current/cloud-server/story-01-002-oci-inventory"
status: "todo"
assignee: ""
reviewer: ""
dependencies: []
parallel_safe: true
modules: ["ansible", "inventory"]
priority: "MUST"
risk_level: "low"
tags: ["ansible", "inventory", "oci"]
due: "2026-06-05"
created_at: "2026-05-29"
updated_at: "2026-05-29"
---

## Summary

Create the Ansible inventory for the OCI cloud server host, including host_vars for host-specific overrides. The inventory must follow the infrahub client-scoped structure under `levonk/active/02-config/ansible/inventories/`.

## Sub-Tasks

- [ ] Create Packer base image for OCI cloud server (pre-inventory):
  - Create `shared/active/01-build/packer/cloud-server.pkr.hcl`
  - Base on `debian:bookworm` AMI/image
  - Pre-install: `python3`, `sudo`, `openssh-server`
  - Configure: `cuser` with UID/GID 1000, passwordless sudo
  - Build via: `just packer-build` or `devbox run packer-build`
  - Validate via: `just packer-validate` or `devbox run packer-validate`
- [ ] Create `levonk/active/02-config/ansible/inventories/oci.yml` defining `cloud_servers` group with the OCI host
- [ ] Add `ansible_host: "{{ cloud_server_ansible_host_ip }}"` (variable-driven, not hardcoded)
- [ ] Add `ansible_user: "{{ cloud_server_admin_user }}"` referencing the admin user variable
- [ ] Add `ansible_ssh_private_key_file` referencing the ed25519 key path variable
- [ ] Create `levonk/active/02-config/ansible/host_vars/oci-cloud-server.yml` for host-specific overrides
- [ ] Add host-level vars for SSH port (`cloud_server_ssh_host_port`)
- [ ] Add host-level vars for VPN mesh preferences (tailscale vs netbird priority)
- [ ] Add host-level var referencing Packer image ID: `cloud_server_ami_id` or `cloud_server_image_id`
- [ ] Document inventory structure in `levonk/active/02-config/ansible/inventories/README.md`
- [ ] Verify inventory parses correctly with `ansible-inventory --list`

## Relevant Files

- `shared/active/01-build/packer/cloud-server.pkr.hcl` — Packer base image definition
- `levonk/active/02-config/ansible/inventories/oci.yml` — OCI cloud server inventory
- `levonk/active/02-config/ansible/host_vars/oci-cloud-server.yml` — host-specific overrides
- `levonk/active/02-config/ansible/group_vars/cloud_server.yml` — group variables (01-001)

## Acceptance Criteria

- [ ] Packer configuration validates successfully (`just packer-validate`)
- [ ] Packer base image builds successfully (`just packer-build`)
- [ ] `ansible-inventory --list -i levonk/active/02-config/ansible/inventories/oci.yml` returns valid JSON
- [ ] No hardcoded IP addresses in inventory files
- [ ] Inventory references variables from group_vars correctly
- [ ] Host is correctly placed in `cloud_servers` group
- [ ] Inventory references Packer image ID variable correctly

## Test Plan

- Packer validate: `devbox run packer-validate`
- Packer build: `devbox run packer-build`
- Inventory parse: `devbox run ansible-inventory --list -i levonk/active/02-config/ansible/inventories/oci.yml`
- Lint: `devbox run ansible-lint levonk/active/02-config/ansible/inventories/`

## Observability

- Add inventory debug task in bootstrap playbook to log host and group membership

## Compliance

- No hardcoded credentials or IP addresses
- SSH keys referenced via variables

## Risks & Mitigations

- Risk: OCI host IP changes after provisioning — Mitigation: Use dynamic inventory or update host_vars
- Risk: Inventory path resolution issues — Mitigation: Test with `ansible-inventory` command

## Dependencies & Sequencing

- Depends on: None (foundation story; parallel with 01-001)
- Unblocks: 02-001..02-014

## Definition of Done

- Inventory parses cleanly, variables resolve, lint passes
- Story file updated to `done`

## Commit Conventions

- `feat(ansible): add OCI cloud server inventory`
- `docs(ansible): document OCI inventory structure`

## Changelog

- 2026-05-29: initialized story file
