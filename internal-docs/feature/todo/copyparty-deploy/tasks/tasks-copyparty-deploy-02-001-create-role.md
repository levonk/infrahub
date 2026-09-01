---
story_id: "02-001"
story_title: "Create storage-copyparty Ansible role"
story_name: "create-role"
prd_name: "copyparty-deploy"
prd_file: "internal-docs/feature/todo/copyparty-deploy/feat-202608312209-copyparty-deploy.md"
phase: 2
parallel_id: 1
branch: "feature/current/copyparty-deploy/story-02-001-create-role"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["01-001"]
parallel_safe: true
modules: ["ansible-role"]
priority: "MUST"
risk_level: "medium"
tags: ["feat", "ansible", "role", "container"]
due: "2026-08-31"
create-date: "2026-08-31"
update-date: "2026-08-31"
---

## Summary

Create the `storage-copyparty` Ansible role under
`shared/active/02-config/ansible/roles/storage-copyparty/` with defaults,
tasks, handlers, meta, templates (config file), and README. The role deploys
copyparty as a Docker container with three volumes (/public, /uploads,
/family), built-in basic auth, and a health check.

## Sub-Tasks

- [ ] Create role directory structure:
  ```
  roles/storage-copyparty/
  ├── defaults/main.yml
  ├── handlers/main.yml
  ├── meta/main.yml
  ├── tasks/main.yml
  ├── templates/copyparty.conf.j2
  └── README.md
  ```
- [ ] Write `defaults/main.yml`:
  - `copyparty_enabled: true`
  - `copyparty_container_name: "copyparty"`
  - `copyparty_image: "copyparty/iv"`
  - `copyparty_image_tag: "latest"`
  - `copyparty_host_port: "{{ infra_port_storage_copyparty_host | default('3923') }}"`
  - `copyparty_container_port: "{{ infra_port_storage_copyparty_container | default('3923') }}"`
  - `copyparty_network_name: "{{ infra_network_proxy_traefik_network_name | default('traefik-network') }}"`
  - `copyparty_domain: "{{ infra_domain_storage_copyparty | default('files.levonk.com') }}"`
  - `copyparty_data_volume: "{{ infra_storage_copyparty_data_volume | default('localnet-copyparty-data-volume') }}"`
  - `copyparty_config_volume: "{{ infra_storage_copyparty_config_volume | default('localnet-copyparty-config-volume') }}"`
  - `copyparty_admin_password: "{{ vault_copyparty_admin_password | default('') }}"`
  - `copyparty_healthcheck_interval: "30s"`
  - `copyparty_healthcheck_timeout: "10s"`
  - `copyparty_healthcheck_retries: 3`
  - `copyparty_healthcheck_start_period: "30s"`
  - `copyparty_verify_health: true`
  - `copyparty_log_max_size: "10m"`
  - `copyparty_log_max_file: "5"`
- [ ] Write `templates/copyparty.conf.j2` — copyparty config file with:
  - `[global]` section: port 3923, `e2dsa` (file indexing), `e2ts` (media tags), `hist: /cfg/hists`, `xff-hdr: X-Forwarded-For`, `rproxy: 1`, bind to `0.0.0.0`
  - `[accounts]` section: `admin: {{ copyparty_admin_password }}`
  - `[/public]` volume: `/w/public`, `accs: r: *` (anonymous read)
  - `[/uploads]` volume: `/w/uploads`, `accs: w: *` (anonymous write-only), `xlink: /public` (uploads appear in public after admin review — OPTIONAL, see copyparty docs; if too complex, just `w: *`)
  - `[/family]` volume: `/w/family`, `accs: rwmda: admin` (admin read/write/move/delete)
  - **IMPORTANT**: copyparty config uses pseudo-YAML with `[section]` headers and 2-space indented keys. Inline comments require TWO spaces before `#`.
- [ ] Write `tasks/main.yml`:
  1. Assert required variables (`copyparty_container_name`, `copyparty_image`, `copyparty_host_port`, `copyparty_admin_password`)
  2. Ensure config volume exists (`community.docker.docker_volume`)
  3. Ensure data volume exists (`community.docker.docker_volume`)
  4. Pull image (`community.docker.docker_image`, `source: pull`)
  5. Deploy config file template to config volume (use `ansible.builtin.tempfile` + `community.docker.docker_cp` OR mount the config volume as a bind mount and use `ansible.builtin.template` — follow the pattern from existing roles like `dashboard-homepage` which uses bind-mounted config dirs)
  6. Deploy container (`community.docker.docker_container`):
     - `name: "{{ copyparty_container_name }}"`
     - `image: "{{ copyparty_image }}:{{ copyparty_image_tag }}"`
     - `state: started`
     - `restart_policy: unless-stopped`
     - `networks: [{ name: "{{ copyparty_network_name }}" }]`
     - `published_ports: ["{{ copyparty_host_port }}:{{ copyparty_container_port }}/tcp"]`
     - `volumes: ["{{ copyparty_data_volume }}:/w", "{{ copyparty_config_volume }}:/cfg"]`
     - `env: { PRTY_CONFIG: "/cfg/copyparty.conf", TZ: "{{ localnet_tz | default('UTC') }}" }`
     - `log_driver: json-file`, `log_options: { max-size: "{{ copyparty_log_max_size }}", max-file: "{{ copyparty_log_max_file }}" }`
     - `security_opts: ["no-new-privileges:true"]`
     - `healthcheck: { test: ["CMD-SHELL", "wget -qO- http://127.0.0.1:{{ copyparty_container_port }}/ >/dev/null 2>&1 || exit 1"], interval: "{{ copyparty_healthcheck_interval }}", timeout: "{{ copyparty_healthcheck_timeout }}", retries: "{{ copyparty_healthcheck_retries }}", start_period: "{{ copyparty_healthcheck_start_period }}" }`
  7. Wait for health (`ansible.builtin.uri` to `http://127.0.0.1:{{ copyparty_host_port }}/`, gated on `copyparty_verify_health`)
  8. Status report (debug msg with URL, container name, status)
- [ ] Write `handlers/main.yml`:
  - `restart copyparty`: `community.docker.docker_container` with `name`, `state: started`, `restart: true`
- [ ] Write `meta/main.yml`:
  - `role_name: storage_copyparty` (underscores for ansible-lint)
  - `author: localnet`
  - `description: Deploy copyparty file sharing server`
  - `license: MIT`
  - `min_ansible_version: "2.9"`
  - `platforms: [{ name: EL, versions: ["8", "9"] }]`
- [ ] Write `README.md` with:
  - Role description
  - Requirements (Docker, Traefik network)
  - Variables table (key variables with defaults)
  - Dependencies (none)
  - Example playbook usage
  - Monitoring section (health endpoint: `/`, no metrics endpoint)
  - Backup section (plain files in Docker volume — standard volume backup)

## Relevant Files

- `shared/active/02-config/ansible/roles/storage-copyparty/defaults/main.yml` — new
- `shared/active/02-config/ansible/roles/storage-copyparty/tasks/main.yml` — new
- `shared/active/02-config/ansible/roles/storage-copyparty/handlers/main.yml` — new
- `shared/active/02-config/ansible/roles/storage-copyparty/meta/main.yml` — new
- `shared/active/02-config/ansible/roles/storage-copyparty/templates/copyparty.conf.j2` — new
- `shared/active/02-config/ansible/roles/storage-copyparty/README.md` — new
- `shared/active/02-config/ansible/roles/dashboard-homepage/tasks/main.yml` — reference pattern
- `shared/active/02-config/ansible/roles/dashboard-homepage/defaults/main.yml` — reference pattern

## Acceptance Criteria (Gherkin)

- Given the role exists, When `ansible-lint` runs on the role, Then no errors are reported
- Given the role defaults, When `copyparty_admin_password` is not set in vault, Then it defaults to empty string (safe fallback)
- Given the config template, When rendered, Then it produces valid copyparty config with `[global]`, `[accounts]`, `[/public]`, `[/uploads]`, `[/family]` sections
- Given the container task, When deployed, Then the container is on `traefik-network` with port 3923 published
- Given the healthcheck, When the container starts, Then `wget` to `http://127.0.0.1:3923/` is used to verify health

## Test Plan

- `just ansible-lint-internal` passes with the new role
- `just ansible-syntax` passes
- Manual review: config template renders valid copyparty pseudo-YAML

## Definition of Done

- All 6 role files created
- `just ansible-lint-internal` passes
- `just ansible-syntax` passes
- No hardcoded IPs/ports/domains (all `infra_*` or role variables)
- `source: pull` in docker_image task
- `community.docker` modules throughout
- Healthcheck durations are strings with unit suffixes
- Handler uses `state: started` + `restart: true`
