---
story: 01-004
name: ansible-role
status: "Todo"
depends: ["01-001", "01-003"]
branch: feature/current/verdaccio-dual-deployment/story-01-004-ansible-role
---

# Story 01-004: Ansible Role artifact-verdaccio

## Goal

Create the `artifact-verdaccio` Ansible role with dual-deployment support (Linux community.docker + Windows ssh CLI pattern).

## Tasks

1. **Role structure** — `shared/active/02-config/ansible/roles/artifact-verdaccio/`
   - `defaults/main.yml` — variables referencing infra_* vars
   - `tasks/main.yml` — main deployment tasks
   - `tasks/deploy-linux.yml` — community.docker path (cno)
   - `tasks/deploy-windows.yml` — ssh CLI path (nl, QM pattern)
   - `templates/config.yaml.j2` — Verdaccio config template
   - `templates/htpasswd.j2` — htpasswd template (bcrypt hash from vault)
   - `handlers/main.yml` — restart handler
   - `meta/main.yml` — Galaxy metadata
   - `README.md` — role documentation

2. **defaults/main.yml** — key variables:
   - `verdaccio_container_name: "localnet-artifact-verdaccio"`
   - `verdaccio_image_name: "verdaccio/verdaccio"` (upstream)
   - `verdaccio_image_tag: "latest"`
   - `verdaccio_host_port: "{{ infra_port_artifact_verdaccio_host | default('4873') }}"`
   - `verdaccio_container_port: "{{ infra_port_artifact_verdaccio_container | default('4873') }}"`
   - `verdaccio_domain_cno: "{{ infra_domain_artifact_verdaccio_cno | default('npmjs.cno.levonk.com') }}"`
   - `verdaccio_domain_nl: "{{ infra_domain_artifact_verdaccio_nl | default('npmjs.nl.levonk.com') }}"`
   - `verdaccio_volume_name: "{{ infra_storage_verdaccio_volume | default('localnet-verdaccio-data-volume') }}"`
   - `verdaccio_network_name: "{{ infra_network_proxy_traefik_network_name | default('traefik-network') }}"`
   - `verdaccio_admin_username: "{{ vault_verdaccio_admin_username | default('levonk-admin') }}"`
   - `verdaccio_admin_password: "{{ vault_verdaccio_admin_password | default('') }}"`
   - Healthcheck vars (string with unit suffix: "30s", "5s", etc.)
   - `verdaccio_docker_host_windows: "ssh://ansible@{{ infra_tailscale_fqdn_windows_docker | default('dtop202311.tale-grouper.ts.net') }}"`

3. **tasks/main.yml** — validate vars, then dispatch to deploy-linux.yml or deploy-windows.yml based on `ansible_os_family` or host group

4. **tasks/deploy-linux.yml** — community.docker.docker_container (cno pattern):
   - docker_volume, docker_image (source: pull), docker_container
   - Mount config dir with rendered config.yaml + htpasswd
   - Join traefik-network
   - Healthcheck: `["CMD-SHELL", "curl -fsS http://127.0.0.1:{{ verdaccio_container_port }}/-/ping || exit 1"]`
   - Wait for health

5. **tasks/deploy-windows.yml** — ssh CLI pattern (nl, QM pattern):
   - `ansible.builtin.shell` + `DOCKER_HOST: ssh://` + `delegate_to: localhost`
   - docker volume create, docker pull, docker run
   - Same config mount, same healthcheck
   - Wait for health via docker inspect

6. **templates/config.yaml.j2** — Verdaccio config:
   - storage: /verdaccio/storage
   - auth: htpasswd (file: /verdaccio/conf/htpasswd, algorithm: bcrypt, max_users: -1)
   - uplinks: npmjs → https://registry.npmjs.org/
   - packages: @levonk/* → access $all, publish $authenticated, proxy npmjs; ** → same
   - listen: 0.0.0.0:{{ verdaccio_container_port }}
   - No LRU eviction (cron job handles cleanup)

7. **templates/htpasswd.j2** — bcrypt htpasswd entry for admin user
   - Use `verdaccio_admin_username` and a bcrypt hash of `verdaccio_admin_password`
   - Ansible can generate bcrypt hash via `password_hash` filter

## Acceptance Criteria

- [ ] Role directory structure complete
- [ ] defaults/main.yml references infra_* vars (no hardcoding)
- [ ] deploy-linux.yml uses community.docker modules
- [ ] deploy-windows.yml uses ssh CLI + delegate_to: localhost (QM pattern)
- [ ] config.yaml.j2 is valid Verdaccio config
- [ ] htpasswd uses bcrypt
- [ ] Healthcheck uses /-/ping endpoint
- [ ] ansible-lint passes on the role
- [ ] No hardcoded IPs or ports

## Implementation Guide

See `.agents/workflows/infrahub-add-new-service.md` Phase 5 (Create the Ansible Role).
Reference roles: `ai-qm` (Windows ssh CLI pattern), `ai-litellm` (Linux community.docker pattern).
