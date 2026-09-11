# Infrahub Conventions for Pipeline Observability Monitoring Stack

**Scope:** Implementation of the six monitoring roles and one playbook described in
`shared/active/08-docs/adr/adr-202608270001-pipeline-observability-strategy.md`.

**Sources of truth**
- ADR: `shared/active/08-docs/adr/adr-202608270001-pipeline-observability-strategy.md`
- Service-adding guide: `.agents/workflows/infrahub-add-new-service.md`
- Shared infrastructure schema: `shared/active/02-config/ansible/infrastructure/`
- Client overrides: `levonk/active/02-config/ansible/infrastructure/`
- Reference compose: `shared/active/03-container/services/monitoring/docker-compose.monitoring.yml`

---

## 1. Shared and Client Infrastructure Status

All required monitoring infrastructure variables already exist in the shared schema; the Levonk client currently inherits them without overrides.

### Ports
- `shared/active/02-config/ansible/infrastructure/ports.yml` lines 554–565 define:
  - `infra_port_monitoring_prometheus_host: "9090"` and `..._container: "9090"`
  - `infra_port_monitoring_grafana_host: "3000"` and `..._container: "3000"`
  - `infra_port_monitoring_loki_host: "3100"` and `..._container: "3100"`
  - `infra_port_monitoring_alertmanager_host: "9093"` and `..._container: "9093"`
  - `infra_port_monitoring_uptime_kuma_host: "3001"` and `..._container: "3001"`
  - `infra_port_monitoring_node_exporter_host: "9100"` and `..._container: "9100"`

- `levonk/active/02-config/ansible/infrastructure/ports.yml` does **not** override any monitoring ports; use the shared values.

### Domains and hostnames
- `shared/active/02-config/ansible/infrastructure/domains.yml` lines 75–84 define:
  - `infra_domain_monitoring_grafana: "grafana.{{ infra_domain_base }}"`
  - `infra_domain_monitoring_alertmanager: "alerts.{{ infra_domain_base }}"`
  - `infra_domain_monitoring_uptime_kuma: "uptime.{{ infra_domain_base }}"`
  - `infra_domain_monitoring_prometheus: "prometheus.{{ infra_domain_base }}"`
  - `infra_hostname_monitoring_prometheus: "localnet-monitoring-prometheus"`
  - `infra_hostname_monitoring_grafana: "localnet-monitoring-grafana"`
  - `infra_hostname_monitoring_loki: "localnet-monitoring-loki"`
  - `infra_hostname_monitoring_alertmanager: "localnet-monitoring-alertmanager"`
  - `infra_hostname_monitoring_uptime_kuma: "localnet-monitoring-uptime-kuma"`
  - `infra_hostname_monitoring_node_exporter: "localnet-monitoring-node-exporter"`

- `levonk/active/02-config/ansible/infrastructure/domains.yml` line 15 sets `infra_domain_base: "levonk.com"`, so the monitoring domains resolve to `grafana.levonk.com`, `alerts.levonk.com`, `uptime.levonk.com`, and `prometheus.levonk.com`.

### Storage
- `shared/active/02-config/ansible/infrastructure/storage.yml` already defines:
  - `infra_storage_monitoring_prometheus_volume`
  - `infra_storage_monitoring_loki_volume`
  - `infra_storage_monitoring_grafana_volume`
  - `infra_storage_monitoring_alertmanager_volume`
  - `infra_storage_monitoring_uptime_kuma_volume`
  - `infra_storage_monitoring_config_dir`
  - `infra_storage_monitoring_node_exporter_textfile_dir`

- `levonk/active/02-config/ansible/infrastructure/storage.yml` does **not** override monitoring storage; use the shared volume names and paths.

### Network
- `shared/active/02-config/ansible/infrastructure/services.yml` lines 1203–1288 catalog each monitoring service with `network: "traefik-network"`.
- `shared/active/02-config/ansible/infrastructure/networks.yml` line 139 defines `infra_network_proxy_traefik_network_name: "traefik-network"`.
- `levonk/active/02-config/ansible/infrastructure/networks.yml` does **not** define a monitoring-specific network; use the shared `traefik-network` for all monitoring containers that require Traefik exposure or internal service discovery.

---

## 2. Ansible Role Conventions

Use the existing well-structured roles as templates: `ai-litellm`, `dns-coredns`, `dashboard-homepage`, and `agentmemory`.

### 2.1 Defaults: `localnet-{service}` container names and infrastructure fallbacks

Container names use the `localnet-{service}` prefix. Defaults must fall back through `infra_*` schemas and then `infra_value_*` or a literal default only as a last resort.

From `shared/active/02-config/ansible/roles/agentmemory/defaults/main.yml` lines 10–13, 26–32, 36–42:

```yaml
agentmemory_container_name: "localnet-agentmemory"
agentmemory_image_name: "{{ local_registry | default(infra_registry) }}/localnet-agentmemory"
agentmemory_image_tag: "latest"

agentmemory_network_name: "traefik-network"
agentmemory_container_ip: "172.31.0.7"

agentmemory_host_port: "{{ infra_port_ai_agentmemory_host | default(infra_port_agentmemory_host) }}"
agentmemory_container_port: "{{ infra_port_ai_agentmemory_container | default(infra_port_agentmemory_container) }}"

agentmemory_volume_name: "localnet-agentmemory-data-volume"
agentmemory_data_dir: "/data"

agentmemory_domain: "{{ infra_domain_ai_agentmemory | default('agentmemory.' ~ (infra_domain_base | default(infra_value_agentmemory_domain))) }}"
```

From `ai-litellm/defaults/main.yml` lines 8, 21–34, 64–68, vault patterns:

```yaml
ai_litellm_container_name: litellm
ai_litellm_image: "ghcr.io/berriai/litellm:main-stable"

ai_litellm_host_port: "{{ infra_port_ai_litellm_host | default(infra_port_dashboard_portainer_host) }}"
ai_litellm_container_port: "{{ infra_port_ai_litellm_container | default(infra_port_dashboard_portainer_host) }}"

ai_litellm_domain: "{{ infra_domain_ai_litellm | default('aigate.' ~ (infra_domain_base | default(infra_value_ai_litellm_domain))) }}"

ai_litellm_master_key: "{{ vault_litellm_master_key | default(infra_value_ai_litellm_master_key) }}"
```

### 2.2 Image references

For monitoring components that use upstream images (Prometheus, Grafana, Loki, Alertmanager, Uptime Kuma, `node_exporter`), set the image variable directly and pull with `source: pull`.

Pattern from `shared/active/02-config/ansible/roles/ai-treg/tasks/main.yml` lines 79–85:

```yaml
- name: Pull treg image
  community.docker.docker_image:
    name: "{{ treg_image_name }}:{{ treg_image_tag }}"
    source: pull
    state: present
  notify: restart treg
```

**Do not use `source: build`.** The local registry fallback is `infra_registry: "100.90.22.85:5000"` (`shared/active/02-config/ansible/infrastructure/timing.yml` line 150).

### 2.3 Healthcheck durations must be string units

`community.docker.docker_container` requires string durations such as `"30s"`, not bare integers. The shared timing schema explicitly defines these:

`shared/active/02-config/ansible/infrastructure/timing.yml` lines 43–53:

```yaml
# Health check intervals (Docker duration strings — require unit suffix)
# community.docker.docker_container requires "30s" not "30" for durations.
infra_healthcheck_interval: "30s"
infra_healthcheck_interval_short: "10s"
infra_healthcheck_timeout: "10s"
infra_healthcheck_start_period: "40s"
infra_healthcheck_retries: "3"
```

Use the shared `infra_*` healthcheck variables in every role. Example from `dns-coredns/tasks/main.yml` lines 67–72:

```yaml
healthcheck:
  test: ["CMD-SHELL", "wget -qO- http://localhost:{{ dns_coredns_metrics_container_port }}/health || exit 1"]
  interval: "{{ infra_healthcheck_interval }}"
  timeout: "{{ infra_healthcheck_timeout }}"
  retries: "{{ infra_healthcheck_retries }}"
  start_period: "{{ infra_healthcheck_start_period }}"
```

### 2.4 `community.docker.docker_container` pattern

From `dns-coredns/tasks/main.yml` lines 40–73:

```yaml
- name: Deploy CoreDNS container
  community.docker.docker_container:
    name: "{{ dns_coredns_container_name }}"
    image: "{{ dns_coredns_image }}:{{ dns_coredns_image_tag }}"
    state: started
    restart_policy: unless-stopped
    command: ["-conf", "/etc/coredns/Corefile"]
    networks:
      - name: "{{ dns_coredns_network_name }}"
    ports:
      - "{{ dns_coredns_host_port }}:{{ dns_coredns_container_port }}/udp"
      - "{{ dns_coredns_host_port }}:{{ dns_coredns_container_port }}/tcp"
      - "{{ dns_coredns_metrics_host_port }}:{{ dns_coredns_metrics_container_port }}/tcp"
    volumes:
      - "{{ dns_coredns_service_dir }}/Corefile:/etc/coredns/Corefile:ro"
      - "{{ dns_coredns_volume_name }}:/var/lib/coredns:rw"
    env:
      TZ: "{{ cloud_server_tz | default('UTC') }}"
    log_driver: json-file
    log_options:
      max-size: "{{ infra_log_max_size }}"
      max-file: "{{ infra_log_max_file }}"
    security_opts:
      - no-new-privileges:true
    read_only: true
    tmpfs:
      - /tmp:mode={{ infra_mode_dir_sticky }},size={{ infra_size_64m }}
    healthcheck:
      ...
  register: dns_coredns_deploy
  notify: restart dns coredns
```

For web services that do not use Docker labels, use `published_ports` (host IP bound) as in `dashboard-homepage/tasks/main.yml` lines 109–110:

```yaml
published_ports:
  - "{{ dashboard_homepage_host_ip }}:{{ dashboard_homepage_host_port }}:{{ dashboard_homepage_container_port }}/tcp"
```

### 2.5 Handlers: `state: started` + `restart: true`, never `state: restarted`

From `proxy-traefik/handlers/main.yml` lines 4–9:

```yaml
- name: restart traefik
  community.docker.docker_container:
    name: "{{ proxy_traefik_container_name }}"
    state: started
    restart: true
  become: true
```

Same pattern from `dns-coredns/handlers/main.yml` lines 4–9:

```yaml
- name: Restart dns coredns
  community.docker.docker_container:
    name: "{{ dns_coredns_container_name }}"
    state: started
    restart: true
  listen: restart dns coredns
```

### 2.6 Validate required variables with `ansible.builtin.assert`

From `ai-litellm/tasks/main.yml` lines 7–19:

```yaml
- name: Validate required variables are defined
  ansible.builtin.assert:
    that:
      - localnet_services_dir is defined
      - shared_container_services_dir is defined
      - ai_litellm_master_key is defined
      - ai_litellm_database_password is defined
    fail_msg: >-
      Missing required variables. Check inventory vars and vault for
      localnet_services_dir, shared_container_services_dir, vault_litellm_master_key,
      vault_litellm_database_password.
    success_msg: "All required litellm variables are defined."
  tags: ["always", "validate"]
```

Each monitoring role must assert its own required variables (service directory, container name, image, host port, volume, and any vault secret).

### 2.7 Volumes and networks

From `ai-litellm/tasks/main.yml` lines 104–139:

```yaml
- name: Ensure LiteLLM data volume exists
  community.docker.docker_volume:
    name: "{{ ai_litellm_volume_name }}"
    state: present

- name: Ensure proxy-chain Docker network exists
  community.docker.docker_network:
    name: "{{ ai_litellm_chain_network_name }}"
    state: present
    driver: bridge
    ipam_config:
      - subnet: "{{ infra_network_ai_proxy_chain_subnet | default(infra_network_ai_subnet) }}"
        gateway: "{{ infra_network_ai_proxy_chain_gateway | default(infra_network_ai_subnet_gateway) }}"
```

For the monitoring stack, create the data volumes and join the existing `traefik-network` rather than defining a new one, unless the ADR is later updated to require a dedicated `monitoring-network`.

---

## 3. Traefik Dynamic Configuration

The repository uses the **file provider**, not the Docker provider, for dynamic routing. Do not add `traefik.*` labels to monitoring containers. Instead, deploy templates to the Traefik dynamic config directory.

### 3.1 Middleware definitions

`shared/active/02-config/ansible/roles/proxy-traefik/templates/dynamic/middlewares.yml.j2` lines 4–23:

```yaml
http:
  middlewares:
    authelia:
      forwardAuth:
        address: "http://{{ proxy_authelia_container_name | default('proxy-authelia') }}:{{ infra_port_proxy_authelia_host }}/api/verify?rd=https://{{ infra_domain_sso_authelia }}"
        trustForwardHeader: true
        authResponseHeaders:
          - Remote-User
          - Remote-Group
          - Remote-Name
          - Remote-Email

    redirect-to-https:
      redirectScheme:
        scheme: https
        permanent: true
```

### 3.2 Example monitoring route: Grafana

Create `shared/active/02-config/ansible/roles/proxy-traefik/templates/dynamic/monitoring-grafana.yml.j2`:

```yaml
# Traefik Dynamic Configuration - Grafana
# Generated by Ansible - DO NOT EDIT MANUALLY
# Domain: {{ infra_domain_monitoring_grafana }}

http:
  routers:
    grafana-http:
      rule: "Host(`{{ infra_domain_monitoring_grafana }}`)"
      entryPoints:
        - web
      middlewares:
        - redirect-to-https
      service: grafana

    grafana-https:
      rule: "Host(`{{ infra_domain_monitoring_grafana }}`)"
      entryPoints:
        - websecure
      middlewares:
        - authelia
      service: grafana
      tls:
        certResolver: letsencrypt

  services:
    grafana:
      loadBalancer:
        servers:
          - url: "http://{{ infra_hostname_monitoring_grafana }}:{{ infra_port_monitoring_grafana_container }}"
        passHostHeader: true
```

### 3.3 Example monitoring route: Alertmanager

`shared/active/02-config/ansible/roles/proxy-traefik/templates/dynamic/monitoring-alertmanager.yml.j2`:

```yaml
http:
  routers:
    alertmanager-http:
      rule: "Host(`{{ infra_domain_monitoring_alertmanager }}`)"
      entryPoints:
        - web
      middlewares:
        - redirect-to-https
      service: alertmanager

    alertmanager-https:
      rule: "Host(`{{ infra_domain_monitoring_alertmanager }}`)"
      entryPoints:
        - websecure
      middlewares:
        - authelia
      service: alertmanager
      tls:
        certResolver: letsencrypt

  services:
    alertmanager:
      loadBalancer:
        servers:
          - url: "http://{{ infra_hostname_monitoring_alertmanager }}:{{ infra_port_monitoring_alertmanager_container }}"
        passHostHeader: true
```

### 3.4 Example monitoring route: Uptime Kuma

`shared/active/02-config/ansible/roles/proxy-traefik/templates/dynamic/monitoring-uptime-kuma.yml.j2`:

```yaml
http:
  routers:
    uptime-kuma-http:
      rule: "Host(`{{ infra_domain_monitoring_uptime_kuma }}`)"
      entryPoints:
        - web
      middlewares:
        - redirect-to-https
      service: uptime-kuma

    uptime-kuma-https:
      rule: "Host(`{{ infra_domain_monitoring_uptime_kuma }}`)"
      entryPoints:
        - websecure
      middlewares:
        - authelia
      service: uptime-kuma
      tls:
        certResolver: letsencrypt

  services:
    uptime-kuma:
      loadBalancer:
        servers:
          - url: "http://{{ infra_hostname_monitoring_uptime_kuma }}:{{ infra_port_monitoring_uptime_kuma_container }}"
        passHostHeader: true
```

The playbook that deploys these should `notify: reload traefik`. The `reload` handler in `proxy-traefik/handlers/main.yml` is a `SIGHUP` via `docker kill --signal=SIGHUP`.

---

## 4. Playbook Conventions

### 4.1 Infrastructure loading pattern

Use `cloud-server-infra.yml` as the reference. From `shared/active/02-config/ansible/playbooks/cloud-server-infra.yml` lines 17–39:

```yaml
pre_tasks:
  - name: "Load shared infrastructure defaults (ports, networks, domains, storage, modes, timing, values)"
    ansible.builtin.include_vars:
      file: "{{ playbook_dir }}/../infrastructure/{{ item }}"
    loop:
      - ports.yml
      - networks.yml
      - domains.yml
      - storage.yml
      - modes.yml
      - timing.yml
      - values.yml
    tags: ["always"]

  - name: "Load client infrastructure overrides (levonk)"
    ansible.builtin.include_vars:
      file: "{{ playbook_dir }}/../../../../../levonk/active/02-config/ansible/infrastructure/{{ item }}"
    loop:
      - ports.yml
      - networks.yml
      - domains.yml
      - storage.yml
    tags: ["always"]
```

### 4.2 Target hosts

The monitoring stack is a cloud-server service. Target `hosts: cloud_servers` with `become: true` and `gather_facts: true`, exactly like `cloud-server-infra.yml` line 12–15 and the `deploy-n8n.yml` playbook line 54–57.

### 4.3 Suggested `deploy-monitoring-stack.yml` skeleton

Create `shared/active/02-config/ansible/playbooks/deploy-monitoring-stack.yml`:

```yaml
---
- name: "Deploy Pipeline Observability Monitoring Stack"
  hosts: cloud_servers
  become: true
  gather_facts: true

  pre_tasks:
    - name: "Load shared infrastructure defaults"
      ansible.builtin.include_vars:
        file: "{{ playbook_dir }}/../infrastructure/{{ item }}"
      loop:
        - ports.yml
        - networks.yml
        - domains.yml
        - storage.yml
        - modes.yml
        - timing.yml
        - values.yml
      tags: ["always"]

    - name: "Load client infrastructure overrides"
      ansible.builtin.include_vars:
        file: "{{ playbook_dir }}/../../../../../levonk/active/02-config/ansible/infrastructure/{{ item }}"
      loop:
        - ports.yml
        - networks.yml
        - domains.yml
        - storage.yml
      tags: ["always"]

  roles:
    - role: monitoring-prometheus
      tags: ["deploy", "monitoring", "prometheus"]
    - role: monitoring-loki
      tags: ["deploy", "monitoring", "loki"]
    - role: monitoring-grafana
      tags: ["deploy", "monitoring", "grafana"]
    - role: monitoring-alertmanager
      tags: ["deploy", "monitoring", "alertmanager"]
    - role: monitoring-uptime-kuma
      tags: ["deploy", "monitoring", "uptime-kuma"]
    - role: monitoring-synthetic-probes
      tags: ["deploy", "monitoring", "probes"]
```

The playbook that exposes the UI services through Traefik should be a separate play or a final play within the same file that loads `proxy-traefik/defaults/main.yml` and deploys the three new dynamic templates under `{{ proxy_traefik_data_dir }}/config/dynamic/`, following `deploy-n8n.yml` lines 103–163.

---

## 5. justfile Recipes

The root `justfile` defines playbook and inventory variables at the top and uses a `_devbox` wrapper. Add monitoring recipes following the same pattern.

From `justfile` lines 17–32, 82–96:

```just
ANSIBLE_ROOT := INFRAHUB_ROOT + "/shared/active/02-config/ansible"
INVENTORY := INFRAHUB_ROOT + "/levonk/active/02-config/ansible/inventories/oci.yml"
```

```just
# Devbox auto-detection
_devbox target *args:
    #!/usr/bin/env bash
    if [ "${DEVBOX_SHELL_ENABLED:-0}" = "1" ]; then
        exec just "{{target}}" {{args}}
    elif command -v devbox >/dev/null 2>&1; then
        exec devbox run -- just "{{target}}" {{args}}
    else
        exit 1
    fi
```

Add these variables near the other `PB_*` definitions:

```just
PB_MONITORING := ANSIBLE_ROOT + "/playbooks/deploy-monitoring-stack.yml"
PB_VAL_MONITORING := ANSIBLE_ROOT + "/playbooks/validate-monitoring-stack.yml"
```

Then add the recipes:

```just
ansible-deploy-monitoring:
    @just _devbox ansible_deploy_monitoring_impl

[private]
ansible_deploy_monitoring_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Deploying monitoring stack"
    ansible-playbook -i {{INVENTORY}} {{PB_MONITORING}} --vault-password-file ~/.ansible/vault_password
```

```just
ansible-validate-monitoring:
    @just _devbox ansible_validate_monitoring_impl

[private]
ansible_validate_monitoring_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Validating monitoring stack"
    ansible-playbook -i {{INVENTORY}} {{PB_VAL_MONITORING}} --vault-password-file ~/.ansible/vault_password
```

For the client-specific `levonk/justfile`, add `levonk-deploy-monitoring` and `levonk-deploy-monitoring-check` using the CNO inventory, matching the existing `levonk-deploy-qm` pattern (lines 490–510).

---

## 6. Reference Compose vs. ADR

The old reference file at `shared/active/03-container/services/monitoring/docker-compose.monitoring.yml` contains:

- Prometheus
- Grafana
- Jaeger
- Blackbox Exporter

It also references Loki and Elasticsearch in `depends_on` without defining those services.

### ADR delta — the following are **authoritative**

The ADR (`adr-202608270001`) explicitly requires:

- Prometheus
- Loki
- Grafana
- Alertmanager
- Uptime Kuma
- Synthetic probes (AI, DNS, web, VPN)
- `node_exporter`

The ADR requires Traefik exposure for:

- Grafana
- Alertmanager
- Uptime Kuma

### Explicitly excluded

**Jaeger is not part of the ADR.** Do not add it merely because it appears in the reference compose. The ADR retains Langfuse for AI tracing and does not introduce a separate tracing backend.

Production deployment must use the Ansible `community.docker` modules, not Docker Compose.

---

## 7. Vault Naming and Handoff

All monitoring secrets belong in the client vault:

`levonk/active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml`

### Required secret names

| Secret | Purpose |
|---|---|
| `vault_grafana_admin_password` | Grafana admin user |
| `vault_monitoring_ntfy_url` | ntfy notification endpoint |
| `vault_monitoring_smtp_*` | SMTP server, port, user, password, from address |
| `vault_monitoring_slack_webhook` | Optional Slack webhook |
| `vault_litellm_synthetic_probe_key` | LiteLLM virtual key for gateway probe (restricted to `gpt-4o-mini`) |
| `vault_omnigent_synthetic_probe_key` | Omnigent API key for full-chain probe |

### Vault edit command

Do **not** edit the vault directly. Provide the user this exact copyable command from `AGENTS.md`:

```bash
docker run --rm -it \
  -v "$HOME/.ansible/vault_password:/vault_password:ro" \
  -v "$HOME/p/gh/levonk/infrahub/levonk/active/02-config/ansible/inventories/group_vars:/vault-dir" \
  -e EDITOR=vi \
  alpine/ansible:latest \
  ansible-vault edit /vault-dir/infrahub-levonk-all.vault.yml --vault-password-file /vault_password
```

The agent must generate secret values (e.g. `openssl rand -hex 32`) and provide the exact YAML lines to add, then wait for the user to confirm the vault has been updated.

---

## 8. Implementation Checklist

1. **Infrastructure** — confirm shared ports/domains/storage are sufficient; no client overrides needed for Levonk.
2. **Six roles** under `shared/active/02-config/ansible/roles/`:
   - `monitoring-prometheus`
   - `monitoring-loki`
   - `monitoring-grafana`
   - `monitoring-alertmanager`
   - `monitoring-uptime-kuma`
   - `monitoring-synthetic-probes`
3. **Traefik dynamic templates** for Grafana, Alertmanager, Uptime Kuma.
4. **Playbook** `shared/active/02-config/ansible/playbooks/deploy-monitoring-stack.yml`.
5. **Validation playbook** `shared/active/02-config/ansible/playbooks/validate-monitoring-stack.yml`.
6. **justfile** recipes `ansible-deploy-monitoring` and `ansible-validate-monitoring`.
7. **Vault** handoff for the six secrets listed above.
8. **No `docker compose`** and no hardcoded ports/IPs in any role or template.

---

## 9. Key Invariants

- Container names: `localnet-monitoring-{component}`.
- Images: pull with `community.docker.docker_image` and `source: pull`; never `source: build`.
- Ports/IPs: always variables from `infra_*` schemas.
- Healthcheck durations: string units such as `"30s"` and `"5s"`.
- Handlers: `state: started` + `restart: true`; never `state: restarted`.
- User namespace remapping: `infra_storage_userns_remap_uid: 100000` and `infra_storage_userns_remap_gid: 100000`.
- Modes: `infra_mode_file`, `infra_mode_dir`, `infra_mode_secret`.
- Secrets: `vault_{service}_{secret}` in the client vault only.
- Jaeger: excluded.
