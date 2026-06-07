---
story_id: "05-003"
story_title: "Deploy infrastructure services to OCI"
story_name: "deploy-infra"
prd_name: "cloud-server"
prd_file: "shared/active/08-docs/reqs/2026/20260529-cloud-server.md"
phase: 5
parallel_id: 3
branch: "feature/current/cloud-server/story-05-003-deploy-infra"
status: "in_progress"
assignee: ""
reviewer: ""
dependencies: ["03-003", "05-002"]
parallel_safe: false
modules: ["ansible", "deploy"]
priority: "SHOULD"
risk_level: "medium"
tags: ["ansible", "deploy", "infra", "oci"]
due: "2026-07-03"
created_at: "2026-05-29"
updated_at: "2026-05-29"
---

## Summary

Execute the `cloud-server-infra.yml` playbook against the OCI host to deploy the infrastructure services: Netbird control plane, DNS, proxy stack, and SSO. These run as Docker containers and depend on the Docker engine and VPN layer being ready.

## Sub-Tasks

- [x] Verify Docker is running and VPN layer is stable
- [x] Run playbook with `--check --diff` first
- [~] Execute: `devbox run ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/cloud-server-infra.yml`
- [ ] Monitor container startup and health
- [ ] Validate post-conditions:
  - Netbird management container responds on variable-driven port
  - DNS container responds to queries
  - Reverse proxy container is running
  - SSO web interface is accessible
  - All container ports match variable definitions
- [ ] Add deployment notes to ticket

## Relevant Files

- `shared/active/02-config/ansible/playbooks/cloud-server-infra.yml`
- `levonk/active/02-config/ansible/inventories/oci.yml`
- `levonk/active/02-config/ansible/group_vars/cloud_server.yml`

## Acceptance Criteria

- [ ] Playbook executes without fatal errors
- [ ] Netbird control plane containers are running
- [ ] DNS service responds to queries
- [ ] Reverse proxy is running and routable
- [ ] SSO service web interface is accessible
- [ ] All service ports are variable-driven

## Test Plan

- Deploy: `devbox run ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/cloud-server-infra.yml`
- Verify Netbird: `curl -s http://<host>:<netbird_mgmt_port>/api/users`
- Verify DNS: `dig @<host> -p <dns_port> google.com`
- Verify Proxy: `curl -s -o /dev/null -w "%{http_code}" http://<host>:<proxy_http_port>/`
- Verify SSO: `curl -s -o /dev/null -w "%{http_code}" http://<host>:<sso_port>/`
- Verify ports: `ssh -i <key> cuser@<host> "docker ps --format '{{.Names}}\t{{.Ports}}'"`

## Observability

- Capture full Ansible output
- Log container status after deployment
- Monitor service response times

## Compliance

- Container ports must match variable definitions
- No hardcoded URLs or credentials

## Risks & Mitigations

- Risk: Service startup ordering issues — Mitigation: Verify Docker Compose `depends_on` or add retry logic
- Risk: Port conflicts with VPN services — Mitigation: Use distinct port ranges per service

## Dependencies & Sequencing

- Depends on: 03-003 (infra playbook), 05-002 (VPN deployed)
- Unblocks: 05-004 (deploy VMs), 06-003 (validate infra)

## Definition of Done

- Infrastructure services deployed and validated on OCI host
- All post-conditions pass
- Story file updated to `done`

## Commit Conventions

- `deploy(ansible): execute cloud-server-infra on OCI`
- `fix(ansible): resolve infrastructure deployment issues`

## Changelog

- 2026-05-29: initialized story file
