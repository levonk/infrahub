---
story_id: "02-001"
story_title: "Create search-hister Ansible role"
story_name: "ansible-role"
prd_name: "hister-search-deploy"
prd_file: "internal-docs/feature/todo/hister-search-deploy/feat-202608222054-hister-search-deploy.md"
phase: 2
parallel_id: 1
branch: "feature/current/hister-search-deploy/story-02-001-ansible-role"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["01-001"]
parallel_safe: true
modules: ["ansible-role", "docker", "windows"]
priority: "MUST"
risk_level: "medium"
tags: ["ansible", "docker", "role", "windows"]
due: "2026-08-22"
create-date: "2026-08-22"
update-date: "2026-08-22"
---

## Summary

Create the `search-hister` Ansible role that deploys the Hister Docker container
on Windows Docker Desktop (dtop202311). Uses the SSH-tunneled Docker CLI pattern
(`DOCKER_HOST: ssh://` + `delegate_to: localhost`) since `community.docker`
modules can't run on Windows.

## Sub-Tasks

- [ ] Create role directory structure under `shared/active/02-config/ansible/roles/search-hister/`
- [ ] Write `defaults/main.yml` with infra_* variable references and safe defaults
- [ ] Write `tasks/main.yml` with validation and dispatch to deploy-windows.yml
- [ ] Write `tasks/deploy-windows.yml` with SSH-tunneled Docker CLI pattern
- [ ] Write `handlers/main.yml` with restart handler
- [ ] Write `meta/main.yml` with Galaxy metadata
- [ ] Write `README.md` with role documentation

## Relevant Files

- `shared/active/02-config/ansible/roles/search-hister/defaults/main.yml`
- `shared/active/02-config/ansible/roles/search-hister/tasks/main.yml`
- `shared/active/02-config/ansible/roles/search-hister/tasks/deploy-windows.yml`
- `shared/active/02-config/ansible/roles/search-hister/handlers/main.yml`
- `shared/active/02-config/ansible/roles/search-hister/meta/main.yml`
- `shared/active/02-config/ansible/roles/search-hister/README.md`

## Acceptance Criteria

- Given the role is included in a playbook targeting windows_docker_hosts, When run, Then it validates required variables
- Given the deploy-windows.yml tasks, When executed, Then they pull the hister image, create a data volume, and deploy the container
- Given the container is deployed, When inspecting it, Then it runs with env vars HISTER__SERVER__ADDRESS=0.0.0.0:4433 and HISTER__SERVER__BASE_URL=https://hister.nl.levonk.com
- Given the role defaults, When rendered, Then all ports/domains/storage reference infra_* variables with safe defaults
- Given the handler, When notified, Then it restarts the container using docker restart via SSH-tunneled CLI

## Implementation Notes

### defaults/main.yml
Reference `infra_*` variables with `| default()` fallbacks. Key variables:
- `search_hister_container_name`: "localnet-hister"
- `search_hister_image_name`: "ghcr.io/asciimoo/hister"
- `search_hister_image_tag`: "latest"
- `search_hister_host_port`: references `infra_port_search_hister_host`
- `search_hister_container_port`: references `infra_port_search_hister_container`
- `search_hister_domain`: references `infra_domain_search_hister`
- `search_hister_volume_name`: references `infra_storage_hister_volume`
- `search_hister_network_name`: references traefik-windows network
- `search_hister_docker_host`: for SSH-tunneled Docker CLI

### tasks/deploy-windows.yml
Follow the pattern from `artifact-verdaccio/tasks/deploy-windows.yml`:
- Use `ansible.builtin.shell`/`command` with `DOCKER_HOST` env var
- `delegate_to: localhost` for all Docker operations
- Pull image, create volume, stop existing container, deploy new container
- Container env vars:
  - `HISTER__SERVER__ADDRESS=0.0.0.0:{{ search_hister_container_port }}`
  - `HISTER__SERVER__BASE_URL=https://{{ search_hister_domain }}`
  - `HISTER__APP__TITLE=Hister`
- Container runs as user `1000:1000` (per upstream image default)
- Join `traefik-windows-network` network
- No published ports needed (Traefik routes via Docker network, not host port)
  — but include host port mapping for direct access if needed
- Healthcheck: `wget -qO- http://127.0.0.1:4433/ || exit 1`

### Reference patterns
- `shared/active/02-config/ansible/roles/artifact-verdaccio/tasks/deploy-windows.yml`
- `shared/active/02-config/ansible/roles/proxy_traefik_windows/tasks/main.yml` (homepage-nl, trala-nl sections)

## Definition of Done

- Role structure complete with all required files
- All Docker operations use SSH-tunneled CLI pattern (no community.docker modules)
- All variables reference `infra_*` with safe defaults
- Handler uses `docker restart` via SSH-tunneled CLI (not `state: restarted`)
- Healthcheck durations are strings with unit suffixes
