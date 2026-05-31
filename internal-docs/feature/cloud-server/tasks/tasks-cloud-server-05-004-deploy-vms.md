---
story_id: "05-004"
story_title: "Deploy VM layer to OCI"
story_name: "deploy-vms"
prd_name: "cloud-server"
prd_file: "shared/active/08-docs/reqs/2026/20260529-cloud-server.md"
phase: 5
parallel_id: 4
branch: "feature/current/cloud-server/story-05-004-deploy-vms"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["03-004", "05-003"]
parallel_safe: false
modules: ["ansible", "deploy"]
priority: "COULD"
risk_level: "medium"
tags: ["ansible", "deploy", "vm", "oci"]
due: "2026-07-03"
created_at: "2026-05-29"
updated_at: "2026-05-29"
---

## Summary

Execute the `cloud-server-vms.yml` playbook against the OCI host to set up the KVM hypervisor and VM networking. This is the foundation for creating individual workload VMs in later phases.

## Sub-Tasks

- [ ] Verify infrastructure services are stable
- [ ] Verify host has virtualization support (`grep -c vmx /proc/cpuinfo` or `svm`)
- [ ] Run playbook with `--check --diff` first
- [ ] Execute: `devbox run ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/cloud-server-vms.yml`
- [ ] Validate post-conditions:
  - `kvm` kernel module is loaded
  - `libvirtd` is running and enabled
  - NAT bridge network is active (`virsh net-list --all`)
  - Routed bridge network is active
  - Storage pool is active (`virsh pool-list --all`)
- [ ] Add deployment notes to ticket

## Relevant Files

- `shared/active/02-config/ansible/playbooks/cloud-server-vms.yml`
- `levonk/active/02-config/ansible/inventories/oci.yml`
- `levonk/active/02-config/ansible/group_vars/cloud_server.yml`

## Acceptance Criteria

- [ ] Playbook executes without fatal errors
- [ ] KVM kernel module is loaded
- [ ] libvirtd is running and enabled
- [ ] NAT and routed bridge networks are active
- [ ] Storage pool is active
- [ ] `virsh` commands work without errors

## Test Plan

- Deploy: `devbox run ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/cloud-server-vms.yml`
- Verify KVM: `ssh -i <key> cuser@<host> "lsmod | grep kvm"`
- Verify libvirt: `ssh -i <key> cuser@<host> "systemctl is-active libvirtd"`
- Verify networks: `ssh -i <key> cuser@<host> "virsh net-list --all"`
- Verify pool: `ssh -i <key> cuser@<host> "virsh pool-list --all"`

## Observability

- Capture full Ansible output
- Log KVM capability and network status

## Compliance

- Bridge subnets must be variables
- No hardcoded storage paths

## Risks & Mitigations

- Risk: Cloud provider doesn't expose virtualization — Mitigation: Pre-check CPU flags; abort gracefully if missing
- Risk: Network bridge conflicts — Mitigation: Use variable-driven names

## Dependencies & Sequencing

- Depends on: 03-004 (VM playbook), 05-003 (infra deployed)
- Unblocks: 06-004 (validate VMs)

## Definition of Done

- VM layer deployed and validated on OCI host
- All post-conditions pass
- Story file updated to `done`

## Commit Conventions

- `deploy(ansible): execute cloud-server-vms on OCI`
- `fix(ansible): resolve VM layer deployment issues`

## Changelog

- 2026-05-29: initialized story file
