# Grafana + Loki + Uptime Kuma — Practical Docker/Ansible Deployment Notes

> Source of truth for tool selection: `shared/active/08-docs/adr/adr-202608270001-pipeline-observability-strategy.md` (Decision, §1). This document only records how to deploy the chosen tools. It does not re-evaluate alternatives.
>
> All containers must be deployed via Ansible `community.docker.docker_container` modules. `docker compose` is never used in production (see root `AGENTS.md` and `shared/active/02-config/ansible/AGENTS.md`).

## Infrastructure variables already in place

- Ports: `shared/active/02-config/ansible/infrastructure/ports.yml` lines 554–565
- Storage: `shared/active/02-config/ansible/infrastructure/storage.yml` lines 298–304

```yaml
infra_port_monitoring_grafana_host: "3000"
infra_port_monitoring_grafana_container: "3000"
infra_port_monitoring_loki_host: "3100"
infra_port_monitoring_loki_container: "3100"
infra_port_monitoring_uptime_kuma_host: "3001"
infra_port_monitoring_uptime_kuma_container: "3001"
infra_port_monitoring_node_exporter_host: "9100"
infra_port_monitoring_node_exporter_container: "9100"
```

## 1. Grafana container image

- **Official image:** `grafana/grafana` ([Docker Hub](https://hub.docker.com/r/grafana/grafana/), [docs](https://grafana.com/docs/grafana/latest/setup-grafana/installation/docker/))
- **Latest stable tag:** `latest` or `latest-slim` are the rolling stable tags; both are multi-arch (`linux/amd64`, `linux/arm64`, `linux/arm/v7`). For reproducibility, pin to a specific stable tag such as `grafana/grafana:<version>`.
- **Data path:** `/var/lib/grafana`
- **Provisioning paths:**
  - Datasources: `/etc/grafana/provisioning/datasources/`
  - Dashboards: `/etc/grafana/provisioning/dashboards/`
- **Config file:** `/etc/grafana/grafana.ini`
- **Environment variables:** any `grafana.ini` value can be overridden with `GF_<SECTION>_<KEY>` (e.g., `GF_SECURITY_ADMIN_PASSWORD`, `GF_SERVER_ROOT_URL`, `GF_USERS_ALLOW_SIGN_UP=false`). ([Configure Docker image](https://grafana.com/docs/grafana/latest/setup-grafana/configure-docker/))
- **Health endpoint:** `GET /api/health` (port 3000)

## 2. Grafana datasource provisioning

Create a `datasources.yml` under the Grafana provisioning path:

```yaml
# /etc/grafana/provisioning/datasources/datasources.yml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
    jsonData:
      timeInterval: 15s

  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    editable: false
    jsonData:
      maxLines: 1000
```

Reference: existing file `shared/active/03-container/configs/monitoring/grafana/datasources.yml` lines 8–24. ([Grafana provisioning docs](https://grafana.com/docs/grafana/latest/administration/provisioning/))

## 3. Grafana dashboard provisioning

Create a `dashboards.yml` provider manifest:

```yaml
# /etc/grafana/provisioning/dashboards/dashboards.yml
apiVersion: 1

providers:
  - name: "Pipeline Dashboards"
    orgId: 1
    folder: "Pipelines"
    type: file
    disableDeletion: false
    updateIntervalSeconds: 30
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
      foldersFromFilesStructure: false
```

Place dashboard JSON files in the `options.path` directory. Grafana loads them on startup and rescans every `updateIntervalSeconds`. Reference: existing file `shared/active/03-container/configs/monitoring/grafana/dashboards/dashboards.yml` lines 6–15. ([Dashboard provisioning docs](https://grafana.com/docs/grafana/latest/administration/provisioning/))

## 4. Grafana dashboard JSON format

A dashboard is a JSON object with a `dashboard` key (or the newer Kubernetes-style `spec` for v12+). The classic shape used for provisioning is:

```json
{
  "dashboard": {
    "id": null,
    "uid": "my-pipeline",
    "title": "Pipeline Health",
    "tags": ["pipeline", "observability"],
    "timezone": "browser",
    "schemaVersion": 41,
    "refresh": "30s",
    "time": {
      "from": "now-6h",
      "to": "now"
    },
    "templating": {
      "list": []
    },
    "panels": []
  },
  "overwrite": true
}
```

Key fields:

- `panels[]` — the visual widgets (timeseries, stat, table, logs, etc.)
- `templating.list[]` — template variables such as `$service`, `$instance`
- `time` — default relative or absolute time range
- `uid` — stable identifier; keep it short
- `schemaVersion` — must match the Grafana version

Where to find example/pipeline-specific dashboards:

- Grafana.com dashboard library: <https://grafana.com/grafana/dashboards/>
- `public/dashboards/` inside the official image
- Create one in the UI, then export JSON from **Dashboard settings → JSON Model** ([JSON model docs](https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/view-dashboard-json-model/))

This research doc does not include a full dashboard JSON. Download or export pipeline dashboards and drop the `.json` files under the provisioning path configured in §3.

## 5. Loki container image

- **Official image:** `grafana/loki` ([Docker Hub](https://hub.docker.com/r/grafana/loki/), [docs](https://grafana.com/docs/loki/latest/setup/install/docker/))
- **Latest stable tag:** `latest` is a rolling multi-arch tag (`linux/amd64`, `linux/arm64`, `linux/arm/v7`); for reproducibility pin to a version such as `grafana/loki:3.7.0` or newer.
- **Config path:** `/etc/loki/local-config.yaml` (built-in default) or a custom file passed with `-config.file=/path/to/loki-config.yaml`
- **Data path:** `/loki`
- **Default mode:** single-node `local-config.yaml`
- **Retention:** configured in `limits_config.retention_period`, enforced by `compactor.retention_enabled`
- **Health:** `GET /ready` (returns 200 when ready)
- **Metrics:** `GET /metrics` (Prometheus format, port 3100)

## 6. Loki config format (single-node, filesystem storage)

A minimal, complete `loki-config.yaml` for a single OCI server:

```yaml
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

compactor:
  working_directory: /loki/compactor
  compaction_interval: 10m
  retention_enabled: true
  retention_delete_delay: 2h
  retention_delete_worker_count: 150

limits_config:
  retention_period: 720h
  reject_old_samples: true
  reject_old_samples_max_age: 168h

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

storage_config:
  boltdb_shipper:
    active_index_directory: /loki/index
    cache_location: /loki/index_cache
    shared_store: filesystem
  filesystem:
    directory: /loki/chunks

ruler:
  alertmanager_url: http://alertmanager:9093
```

Notes:

- Mount this file into the container and start Loki with `command: ["-config.file=/etc/loki/config/loki-config.yaml"]`.
- Retention only works when `compactor.retention_enabled: true` and a global `limits_config.retention_period` is set. Minimum is `24h`. ([Retention docs](https://grafana.com/docs/loki/latest/operations/storage/retention))
- For Loki 3.x, `tsdb` is the preferred index store; the `schema_config.store` can be switched to `tsdb` with `schema: v13` and `storage_config.tsdb_shipper` when the deployment is upgraded.

## 7. Uptime Kuma container image

- **Official image:** `louislam/uptime-kuma` ([Docker Hub](https://hub.docker.com/r/louislam/uptime-kuma/), [GitHub](https://github.com/louislam/uptime-kuma))
- **Latest stable tag:** `2` (recommended, multi-arch: `linux/amd64`, `linux/arm64`, `linux/arm/v7`). The legacy `1` tag is still available but is no longer the recommended stream; it has ARM64 builds, e.g., `1.23.11-alpine` ([Wiki — Docker tags](https://github.com/louislam/uptime-kuma-wiki/blob/master/Docker-Tags.md)).
- **Data path:** `/app/data` (SQLite file; must be persisted)
- **Port:** 3001
- **Health endpoint:** `GET /api/health` (port 3001) — note that the container may not include `curl`, so a `node` one-liner or `wget` health check is safer.
- **No built-in `/metrics` endpoint:** Uptime Kuma is a monitor, not a metrics source. It does not natively expose Prometheus metrics.
- Use a volume for `/app/data` and avoid NFS/SMB for SQLite. ([Install docs](https://github.com/louislam/uptime-kuma/wiki/%F0%9F%94%A7-How-to-Install))

## 8. Uptime Kuma API

Uptime Kuma does not expose a REST API. It uses a **Socket.IO** API.

- **Programmatic option:** the [uptime-kuma-api](https://pypi.org/project/uptime-kuma-api/) Python wrapper ([GitHub](https://github.com/lucasheld/uptime-kuma-api), [docs](https://uptime-kuma-api.readthedocs.io/)).
- **Ansible option:** the [lucasheld/ansible-uptime-kuma](https://github.com/lucasheld/ansible-uptime-kuma) collection wraps the Python library.
- **Typical workflow:** start the container, create the admin account in the web UI, then either manually configure monitors or use the Socket.IO wrapper. There is no native `community.docker` way to provision monitors; use a separate Python script/collection or configure by hand.

Example with the Python wrapper:

```python
from uptime_kuma_api import UptimeKumaApi, MonitorType

with UptimeKumaApi('http://127.0.0.1:3001') as api:
    api.login('admin', '{{ vault_uptime_kuma_admin_password }}')
    api.add_monitor(
        type=MonitorType.HTTP,
        name='Traefik API',
        url='https://traefik.{{ infra_domain_base }}/ping'
    )
```

## 9. Ansible `community.docker` examples

### Pull images

```yaml
- name: Pull Grafana image
  community.docker.docker_image:
    name: "{{ grafana_image_name }}:{{ grafana_image_tag }}"
    source: pull
    state: present

- name: Pull Loki image
  community.docker.docker_image:
    name: "{{ loki_image_name }}:{{ loki_image_tag }}"
    source: pull
    state: present

- name: Pull Uptime Kuma image
  community.docker.docker_image:
    name: "{{ uptime_kuma_image_name }}:{{ uptime_kuma_image_tag }}"
    source: pull
    state: present
```

### Grafana

```yaml
- name: Deploy Grafana container
  community.docker.docker_container:
    name: "{{ grafana_container_name }}"
    image: "{{ grafana_image_name }}:{{ grafana_image_tag }}"
    state: started
    restart_policy: unless-stopped
    networks:
      - name: "{{ monitoring_network_name }}"
    published_ports:
      - "{{ infra_port_monitoring_grafana_host }}:{{ infra_port_monitoring_grafana_container }}/tcp"
    volumes:
      - "{{ monitoring_grafana_config_dir }}/datasources.yml:/etc/grafana/provisioning/datasources/datasources.yml:ro"
      - "{{ monitoring_grafana_dashboards_dir }}:/etc/grafana/provisioning/dashboards:ro"
      - "{{ monitoring_grafana_volume }}:/var/lib/grafana:rw"
    env:
      TZ: "{{ cloud_server_tz | default('UTC') }}"
      GF_SECURITY_ADMIN_PASSWORD: "{{ vault_grafana_admin_password | default('change-me') }}"
      GF_USERS_ALLOW_SIGN_UP: "false"
      GF_SERVER_ROOT_URL: "https://{{ infra_domain_monitoring_grafana }}"
    log_driver: json-file
    log_options:
      max-size: "{{ infra_log_max_size | default('10m') }}"
      max-file: "{{ infra_log_max_file | default('5') }}"
    healthcheck:
      test: ["CMD-SHELL", "wget --spider -q http://127.0.0.1:{{ infra_port_monitoring_grafana_container }}/api/health || exit 1"]
      interval: "{{ grafana_healthcheck_interval | default('30s') }}"
      timeout: "{{ grafana_healthcheck_timeout | default('5s') }}"
      retries: "{{ grafana_healthcheck_retries | default(3) | int }}"
      start_period: "{{ grafana_healthcheck_start_period | default('30s') }}"
```

### Loki

```yaml
- name: Deploy Loki container
  community.docker.docker_container:
    name: "{{ loki_container_name }}"
    image: "{{ loki_image_name }}:{{ loki_image_tag }}"
    state: started
    restart_policy: unless-stopped
    command:
      - "-config.file=/etc/loki/config/loki-config.yaml"
    networks:
      - name: "{{ monitoring_network_name }}"
    published_ports:
      - "{{ infra_port_monitoring_loki_host }}:{{ infra_port_monitoring_loki_container }}/tcp"
    volumes:
      - "{{ monitoring_loki_config_dir }}/loki-config.yaml:/etc/loki/config/loki-config.yaml:ro"
      - "{{ monitoring_loki_volume }}:/loki:rw"
    env:
      TZ: "{{ cloud_server_tz | default('UTC') }}"
    log_driver: json-file
    log_options:
      max-size: "{{ infra_log_max_size | default('10m') }}"
      max-file: "{{ infra_log_max_file | default('5') }}"
    healthcheck:
      test: ["CMD-SHELL", "wget --spider -q http://127.0.0.1:{{ infra_port_monitoring_loki_container }}/ready || exit 1"]
      interval: "{{ loki_healthcheck_interval | default('30s') }}"
      timeout: "{{ loki_healthcheck_timeout | default('5s') }}"
      retries: "{{ loki_healthcheck_retries | default(3) | int }}"
      start_period: "{{ loki_healthcheck_start_period | default('30s') }}"
```

### Uptime Kuma

```yaml
- name: Deploy Uptime Kuma container
  community.docker.docker_container:
    name: "{{ uptime_kuma_container_name }}"
    image: "{{ uptime_kuma_image_name }}:{{ uptime_kuma_image_tag }}"
    state: started
    restart_policy: unless-stopped
    networks:
      - name: "{{ monitoring_network_name }}"
    published_ports:
      - "{{ infra_port_monitoring_uptime_kuma_host }}:{{ infra_port_monitoring_uptime_kuma_container }}/tcp"
    volumes:
      - "{{ monitoring_uptime_kuma_volume }}:/app/data:rw"
    env:
      TZ: "{{ cloud_server_tz | default('UTC') }}"
      DATA_DIR: "/app/data"
    log_driver: json-file
    log_options:
      max-size: "{{ infra_log_max_size | default('10m') }}"
      max-file: "{{ infra_log_max_file | default('5') }}"
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://127.0.0.1:{{ infra_port_monitoring_uptime_kuma_container }}/api/health || exit 1"]
      interval: "{{ uptime_kuma_healthcheck_interval | default('30s') }}"
      timeout: "{{ uptime_kuma_healthcheck_timeout | default('10s') }}"
      retries: "{{ uptime_kuma_healthcheck_retries | default(3) | int }}"
      start_period: "{{ uptime_kuma_healthcheck_start_period | default('30s') }}"
```

## 10. node_exporter

- **Image:** `prom/node-exporter` ([Docker Hub](https://hub.docker.com/r/prom/node-exporter/), [GitHub](https://github.com/prometheus/node_exporter))
- **Port:** 9100
- **Metrics endpoint:** `GET /metrics`
- **Host mounts:** `/proc`, `/sys`, `/`

`community.docker.docker_container` task:

```yaml
- name: Pull node_exporter image
  community.docker.docker_image:
    name: "{{ node_exporter_image_name }}:{{ node_exporter_image_tag }}"
    source: pull
    state: present

- name: Deploy node_exporter container
  community.docker.docker_container:
    name: "{{ node_exporter_container_name }}"
    image: "{{ node_exporter_image_name }}:{{ node_exporter_image_tag }}"
    state: started
    restart_policy: unless-stopped
    command:
      - "--path.rootfs=/host"
    networks:
      - name: "{{ monitoring_network_name }}"
    published_ports:
      - "{{ infra_port_monitoring_node_exporter_host }}:{{ infra_port_monitoring_node_exporter_container }}/tcp"
    volumes:
      - "/proc:/host/proc:ro"
      - "/sys:/host/sys:ro"
      - "/:/host:ro,rslave"
    env:
      TZ: "{{ cloud_server_tz | default('UTC') }}"
    log_driver: json-file
    log_options:
      max-size: "{{ infra_log_max_size | default('10m') }}"
      max-file: "{{ infra_log_max_file | default('5') }}"
```

The `/:/host:ro,rslave` mount exposes the host root filesystem for the textfile collector. Prometheus scrapes `http://{{ ansible_host }}:{{ infra_port_monitoring_node_exporter_host }}/metrics`.

## References

- Grafana Docker: <https://grafana.com/docs/grafana/latest/setup-grafana/installation/docker/>
- Grafana Docker configuration: <https://grafana.com/docs/grafana/latest/setup-grafana/configure-docker/>
- Grafana provisioning: <https://grafana.com/docs/grafana/latest/administration/provisioning/>
- Grafana dashboard JSON model: <https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/view-dashboard-json-model/>
- Grafana dashboards library: <https://grafana.com/grafana/dashboards/>
- Loki Docker install: <https://grafana.com/docs/loki/latest/setup/install/docker/>
- Loki config examples: <https://grafana.com/docs/loki/latest/configure/examples/>
- Loki retention: <https://grafana.com/docs/loki/latest/operations/storage/retention>
- Uptime Kuma install wiki: <https://github.com/louislam/uptime-kuma/wiki/%F0%9F%94%A7-How-to-Install>
- Uptime Kuma Docker tags: <https://github.com/louislam/uptime-kuma-wiki/blob/master/Docker-Tags.md>
- uptime-kuma-api Python library: <https://github.com/lucasheld/uptime-kuma-api>
- node_exporter Docker: <https://hub.docker.com/r/prom/node-exporter/>
- node_exporter README: <https://github.com/prometheus/node_exporter>
