---
story_id: "05-003"
story_title: "Deploy infrastructure services to OCI"
story_name: "deploy-infra"
prd_name: "cloud-server"
prd_file: "shared/active/08-docs/reqs/2026/20260529-cloud-server.md"
phase: 5
parallel_id: 3
branch: "feature/current/cloud-server/story-05-003-deploy-infra"
status: "blocked"
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
- [x] Execute: `devbox run ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/cloud-server-infra.yml`
- [!] Monitor container startup and health - BLOCKED: NetBird containers require configuration file
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

## Blocker Notes

**BLOCKER (2026-06-07)**: NetBird control plane containers fail to start due to missing configuration file.

**Issue**: The NetBird management container crashes with error:
```
Error: failed reading provided config file: /etc/netbird/management.json: open /etc/netbird/management.json: no such file or directory
```

**Root Cause**: The `vpn-netbird-control` role attempts to configure NetBird services solely through environment variables, but the NetBird containers require a configuration file mounted at `/etc/netbird/management.json` (and corresponding files for signal/relay services).

**Current State**:
- NetBird management container: Restarting (exit code 1)
- NetBird signal container: Up but unhealthy
- NetBird relay container: Restarting (exit code 1)

**Required Fix**: The role needs to:
1. Add configuration file templates for NetBird management, signal, and relay services
2. Mount these configuration files into the containers via Docker volumes
3. Properly configure the NetBird services with required settings (database, OIDC, etc.)

**Alternative**: Consider using a different approach for NetBird deployment or skip NetBird control plane if not immediately required for the infrastructure services.

**Impact**: This blocks the entire infrastructure deployment since the playbook fails when NetBird containers don't become healthy.

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
