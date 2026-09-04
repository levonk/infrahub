---
story_id: "05-001"
story_title: "Ansible role devops-no-mistakes"
story_name: "ansible-role"
prd_name: "no-mistakes-shared-gate"
prd_file: "internal-docs/feature/todo/no-mistakes-shared-gate/feat-202608231257-no-mistakes-shared-gate.md"
phase: 5
parallel_id: 1
branch: "feature/current/no-mistakes-shared-gate/story-05-001-ansible-role"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["01-002", "03-001", "04-001"]
parallel_safe: false
modules: ["ansible", "role"]
priority: "MUST"
risk_level: "medium"
tags: ["ansible", "role", "deploy"]
due: "2026-08-23"
create-date: "2026-08-23"
update-date: "2026-08-23"
---

## Summary

Create the `devops-no-mistakes` Ansible role that deploys the no-mistakes container to dtop202311 (Windows Docker Desktop) using the SSH-tunneled Docker CLI pattern.

## Sub-Tasks

- [ ] Create role directory structure:
  ```
  shared/active/02-config/ansible/roles/devops-no-mistakes/
  ├── defaults/main.yml
  ├── handlers/main.yml
  ├── meta/main.yml
  ├── tasks/main.yml
  ├── templates/
  │   ├── config.yaml.j2          # no-mistakes global config
  │   ├── authorized_keys.j2      # SSH authorized_keys for gate user
  │   └── entrypoint.sh.j2        # Container entrypoint
  └── README.md
  ```
- [ ] Create `defaults/main.yml`:
  - Container name: `localnet-no-mistakes`
  - Image: `{{ local_registry | default('100.90.22.85:5000') }}/localnet-devops-no-mistakes`
  - Tag: `latest`
  - Ports: reference `infra_port_devops_no_mistakes_ssh_host/container`
  - Domain: reference `infra_domain_devops_no_mistakes`
  - Volume: reference `infra_storage_no_mistakes_volume`
  - Network: `traefik-windows-network`
  - Healthcheck: string durations ("30s", "5s", 3 retries, "30s" start period)
  - Secrets: reference vault vars with `| default('')` fallbacks
  - Docker host: `ssh://ansible@{{ windows_tailscale_hostname }}.{{ infra_tailscale_tailnet }}`
- [ ] Create `tasks/main.yml`:
  - Validate required variables (assert)
  - Pull image (docker pull via DOCKER_HOST ssh://, delegate_to: localhost)
  - Create data volume (docker volume create)
  - Create config volume (docker volume create)
  - Write config.yaml to temp dir (template task, delegate_to: localhost)
  - Write authorized_keys to temp dir (template task, delegate_to: localhost)
  - Write entrypoint.sh to temp dir (template task, delegate_to: localhost)
  - Stop existing container (docker rm -f)
  - Deploy container (docker run with: -d, --restart unless-stopped, -p SSH port, -v data volume, -v config volume, --network, env vars for GITHUB_TOKEN, DEVIN_API_KEY, --health-cmd)
  - Copy config files into container (docker cp)
  - Status report (docker inspect)
- [ ] Create `handlers/main.yml`:
  - `restart no-mistakes`: docker_container state: started, restart: true (via docker CLI)
- [ ] Create `meta/main.yml`:
  - galaxy_info with role_name, author, description, license, min_ansible_version, platforms
- [ ] Create templates:
  - `config.yaml.j2`: no-mistakes global config (agent: acp:devin, acpx_path, acp_registry_overrides)
  - `authorized_keys.j2`: SSH public key for gate user
  - `entrypoint.sh.j2`: Container entrypoint (start sshd + daemon)
- [ ] Create `README.md`

## Relevant Files

- `shared/active/02-config/ansible/roles/devops-no-mistakes/defaults/main.yml`
- `shared/active/02-config/ansible/roles/devops-no-mistakes/tasks/main.yml`
- `shared/active/02-config/ansible/roles/devops-no-mistakes/handlers/main.yml`
- `shared/active/02-config/ansible/roles/devops-no-mistakes/meta/main.yml`
- `shared/active/02-config/ansible/roles/devops-no-mistakes/templates/config.yaml.j2`
- `shared/active/02-config/ansible/roles/devops-no-mistakes/templates/authorized_keys.j2`
- `shared/active/02-config/ansible/roles/devops-no-mistakes/templates/entrypoint.sh.j2`
- `shared/active/02-config/ansible/roles/devops-no-mistakes/README.md`

## Acceptance Criteria

- Given the role, When `ansible-playbook --syntax-check` runs, Then no syntax errors
- Given the role, When `ansible-playbook --check` runs against windows-docker inventory, Then check mode passes
- Given the role defaults, When inspecting, Then all IPs/ports/domains reference `infra_*` variables (no hardcoding)
- Given the role defaults, When inspecting secrets, Then all secrets reference `vault_*` variables with `| default('')`
- Given the container task, When inspecting, Then `source: pull` is used (never `source: build`)
- Given the handler, When inspecting, Then `state: started` + `restart: true` (not `state: restarted`)
- Given the healthcheck, When inspecting durations, Then all are strings with unit suffixes

## Test Plan

- `devbox run -- just ansible-lint-internal` passes
- `devbox run -- rtk ansible-playbook --syntax-check` on the role's tasks
- `devbox run -- rtk ansible-playbook --check` against windows-docker inventory (dry run)

## Definition of Done

Role created, lint passes, syntax check passes, all checklist items from infrahub-add-new-service.md satisfied.

## Implementation Guide Reference

Follows `infrahub-add-new-service.md` Phase 5 (5a-5f: role naming, structure, defaults, tasks, handlers, meta).
Uses the Windows Docker Desktop SSH-tunneled pattern (like `career-jobops` role).
See `infrahub-container-deploy` skill for userns-remap, vault handoff, infra_ naming.

## Key Design Notes

- **Windows Docker pattern**: Use `ansible.builtin.shell` with `DOCKER_HOST: ssh://` and `delegate_to: localhost` (community.docker modules can't run on Windows)
- **No Traefik routing**: SSH traffic doesn't go through Traefik. The container joins `traefik-windows-network` for cross-machine visibility but SSH is direct.
- **Config injection**: Templates are rendered locally, then `docker cp` into the container after start
- **Secret injection**: GITHUB_TOKEN and DEVIN_API_KEY passed as env vars to the container
