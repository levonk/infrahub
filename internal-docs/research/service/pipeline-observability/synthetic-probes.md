# Synthetic Monitoring Probes — Practical Implementation Patterns

**Context:** ADR-202608270001 Pipeline Observability Strategy, §4 Synthetic Probes (`/Users/micro/p/gh/levonk/infrahub/shared/active/08-docs/adr/adr-202608270001-pipeline-observability-strategy.md`).
**Status:** Research notes for the implementation subagent that will build the `monitoring-synthetic-probes` Ansible role.

---

## 1. Probe execution patterns

ADR §4 (lines 465-653) defines four synthetic probes that exercise the whole chain:

| Probe | Entry point | ADR spec lines |
|---|---|---|
| AI | LiteLLM `/v1/chat/completions` and Omnigent session API | 474-585 |
| DNS | internal, external and DNSSEC resolution | 586-610 |
| Web proxy | HTTP request through the MITM/ Privoxy/ Varnish/ Gost chain | 611-629 |
| VPN/Egress | NordVPN, Tor and Tailscale egress validation | 630-653 |

Three execution patterns are considered. All three can coexist; the implementation uses **(a)** for the ADR probes and **(b)** as an optional helper for simple HTTP/TCP checks.

### 1(a) Shell scripts in a cron container (alpine + curl + jq + cron)

**When it fits:** The ADR-specified probes. These need real LLM requests, token validation, `jq` JSON path checks, `dig`, `curl --proxy`, `curl --socks5`, IP comparison and `tailscale status`.

**Pros:**
- Exact logic required by the ADR: parse JSON with `jq`, compare IPs, run `dig`, run `curl --socks5`, etc.
- Easy to write, review and version in `monitoring-synthetic-probes/templates/*.sh.j2`.
- Works with the textfile collector, which fits the existing `node_exporter` deployment.

**Cons:**
- One more container to deploy and schedule.
- Scripts can drift; keep them short and keep logic in shared templates.

**ADR mapping:** All four probes in §4.1-§4.4 map directly to this approach.

### 1(b) Prometheus blackbox_exporter

**When it fits:** Generic HTTP/TCP/ICMP/DNS reachability where the only success criterion is status code / connection / A-record response. Good as a **supplement** for simple service health (e.g. `https://litellm.<base>/health` or `tcp_connect` to the MITM proxy port).

**Pros:**
- Official image, no custom code.
- Excellent for many URLs / ports via a single scrape config with relabeling.
- Native Prometheus metrics (`probe_success`, `probe_duration_seconds`).

**Cons:**
- Cannot execute the ADR probe logic:
  - cannot run an LLM request and check `usage.total_tokens exists` / `choices[0].message.content contains "OK"`;
  - cannot chain through MITM/ Privoxy/ Varnish/ Gost with per-hop proxy logic;
  - cannot run `curl --socks5` or `tailscale status` and compare IP;
  - limited body validation (regex/CEL) compared to `jq`.
- Needs ICMP `NET_RAW` capability or root.

**ADR mapping:** Useful for simple TCP/HTTP per-node checks, but **not** for the four synthetic probes in §4.

### 1(c) Custom sidecar that pushes to Pushgateway

**When it fits:** Short-lived batch jobs that are not tied to a host and run inside short-lived pods.

**Pros:**
- Solves the "job exits before Prometheus scrapes" problem.

**Cons:**
- Pushgateway never forgets series unless you delete them; stale metrics are a real risk.
- No `up` metric for the probe itself; you must also monitor Pushgateway.
- Extra container and network hop.

**ADR mapping:** Works for cron probes, but the textfile collector is simpler because `node_exporter` is already deployed.

---

## 2. blackbox_exporter reference configuration

### 2.1 Image

Official image: `prom/blackbox-exporter` (also mirrored on Quay as `quay.io/prometheus/blackbox-exporter`).
Source: https://github.com/prometheus/blackbox_exporter, https://prometheus.io/docs/guides/multi-target-exporter/.

### 2.2 `blackbox.yml`

The format is `modules:` with named modules. Each module has a `prober:` (`http`, `tcp`, `icmp`, `dns`, `grpc`) and one prober-specific block.

```yaml
modules:
  http_2xx:
    prober: http
    timeout: 10s
    http:
      valid_http_versions: ["HTTP/1.1", "HTTP/2.0"]
      valid_status_codes: [200]
      method: GET
      follow_redirects: false
      fail_if_ssl: false
      fail_if_not_ssl: false
      preferred_ip_protocol: "ip4"
      ip_protocol_fallback: true

  tcp_connect:
    prober: tcp
    timeout: 5s
    tcp:
      preferred_ip_protocol: "ip4"
      ip_protocol_fallback: true
```

For HTTP probes blackbox can do body **regex** (`fail_if_body_matches_regexp`, `fail_if_body_not_matches_regexp`) and, in recent versions, a CEL expression against JSON (`fail_if_body_json_not_matches_cel`). Those still do not implement the ADR checks cleanly, so a custom script is preferred for the LLM probes.

### 2.3 Prometheus scrape config

Prometheus does **not** scrape the target directly. It scrapes `http://blackbox:9115/probe?target=<target>&module=<module>` and passes the target via relabeling.

```yaml
scrape_configs:
  # Exporter self-metrics
  - job_name: blackbox_exporter
    static_configs:
      - targets: ["{{ infra_network_ip_monitoring_blackbox }}:{{ infra_port_monitoring_blackbox_container }}"]

  # Probes
  - job_name: blackbox
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets:
        - "http://{{ infra_domain_ai_litellm }}/health"
        - "http://{{ infra_domain_proxy_mitm }}:{{ infra_port_proxy_mitm_adblock_container }}"
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: "{{ infra_network_ip_monitoring_blackbox }}:{{ infra_port_monitoring_blackbox_container }}"
```

The same pattern works for `tcp_connect` by setting `params: module: [tcp_connect]` and listing `host:port` targets.

---

## 3. AI pipeline probe — `ai-probe.sh` (LiteLLM entry)

Runs the LiteLLM OpenAI-compatible probe described in ADR §4.1 lines 537-570.

```bash
#!/bin/sh
set -u

: "${LITELLM_ENDPOINT:?LITELLM_ENDPOINT is required}"
: "${LITELLM_API_KEY:?LITELLM_API_KEY is required}"
TIMEOUT="${LITELLM_TIMEOUT:-30}"
METRICS_DIR="${METRICS_DIR:-/var/lib/node_exporter/textfile_collector/probes}"
METRIC_FILE="${METRICS_DIR}/ai_litellm_probe.prom"

OUTFILE=$(mktemp)
trap 'rm -f "$OUTFILE"' EXIT

PAYLOAD='{
  "model": "gpt-4o-mini",
  "messages": [{"role": "user", "content": "Reply with exactly: OK"}],
  "max_tokens": 5,
  "temperature": 0
}'

HTTP_CODE=$(curl -sS -m "$TIMEOUT" -o "$OUTFILE" -w '%{http_code}' \
  -H "Authorization: Bearer $LITELLM_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  "$LITELLM_ENDPOINT/v1/chat/completions" 2>/dev/null) || true

HTTP_CODE=${HTTP_CODE:-000}
SUCCESS=0

if [ "$HTTP_CODE" = "200" ]; then
  if jq -e '
    (.usage.total_tokens != null) and
    ((.choices[0].message.content // "") | contains("OK"))
  ' "$OUTFILE" >/dev/null 2>&1; then
    SUCCESS=1
  fi
fi

mkdir -p "$METRICS_DIR"
cat > "$METRIC_FILE" <<EOF
# HELP ai_pipeline_probe_success Synthetic AI pipeline probe result
# TYPE ai_pipeline_probe_success gauge
ai_pipeline_probe_success{probe="litellm",pipeline="ai"} $SUCCESS
EOF

[ "$SUCCESS" -eq 1 ] && exit 0 || exit 1
```

### Omnigent entry-point variant

Uses the ADR §4.1 Omnigent probe spec (lines 501-535).

```bash
#!/bin/sh
set -u

: "${OMNIGENT_ENDPOINT:?OMNIGENT_ENDPOINT is required}"
: "${OMNIGENT_API_KEY:?OMNIGENT_API_KEY is required}"
TIMEOUT="${OMNIGENT_TIMEOUT:-30}"
METRICS_DIR="${METRICS_DIR:-/var/lib/node_exporter/textfile_collector/probes}"
METRIC_FILE="${METRICS_DIR}/ai_omnigent_probe.prom"

OUTFILE=$(mktemp)
trap 'rm -f "$OUTFILE"' EXIT

PAYLOAD='{"action":"probe","prompt":"Reply with exactly: OK","max_tokens":5}'

HTTP_CODE=$(curl -sS -m "$TIMEOUT" -o "$OUTFILE" -w '%{http_code}' \
  -H "Authorization: Bearer $OMNIGENT_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  "$OMNIGENT_ENDPOINT/api/v1/sessions" 2>/dev/null) || true

HTTP_CODE=${HTTP_CODE:-000}
SUCCESS=0

if [ "$HTTP_CODE" = "200" ]; then
  if jq -e '
    (.usage.total_tokens != null) and
    ((.response.content // "") | contains("OK"))
  ' "$OUTFILE" >/dev/null 2>&1; then
    SUCCESS=1
  fi
fi

mkdir -p "$METRICS_DIR"
cat > "$METRIC_FILE" <<EOF
# HELP ai_pipeline_probe_success Synthetic AI pipeline probe result
# TYPE ai_pipeline_probe_success gauge
ai_pipeline_probe_success{probe="omnigent",pipeline="ai"} $SUCCESS
EOF

[ "$SUCCESS" -eq 1 ] && exit 0 || exit 1
```

### How the metrics reach Prometheus

Recommended: the cron container writes `*.prom` files to a directory shared with `node_exporter` (textfile collector). Prometheus then gets the metrics for free when it scrapes `node_exporter` — no extra network hop and no stale Pushgateway series.

---

## 4. DNS probe — `dns-probe.sh`

ADR §4.2 (lines 586-610).

```bash
#!/bin/sh
set -u

TIMEOUT="${DNS_TIMEOUT:-10}"
INTERNAL="${DNS_INTERNAL_DOMAIN:?DNS_INTERNAL_DOMAIN is required}"
EXTERNAL="cloudflare.com"
DNSSEC="dnssec-test.dnssec-tools.org"
METRICS_DIR="${METRICS_DIR:-/var/lib/node_exporter/textfile_collector/probes}"
METRIC_FILE="${METRICS_DIR}/dns_pipeline_probe.prom"

resolve() {
  dig +short +time="$TIMEOUT" "$1" >/dev/null 2>&1
}

OK_INTERNAL=0
OK_EXTERNAL=0
OK_DNSSEC=0

resolve "$INTERNAL" && OK_INTERNAL=1
resolve "$EXTERNAL" && OK_EXTERNAL=1
resolve "$DNSSEC" && OK_DNSSEC=1

mkdir -p "$METRICS_DIR"
cat > "$METRIC_FILE" <<EOF
# HELP dns_pipeline_probe_success Synthetic DNS pipeline probe result
# TYPE dns_pipeline_probe_success gauge
dns_pipeline_probe_success{query="internal"} $OK_INTERNAL
dns_pipeline_probe_success{query="external"} $OK_EXTERNAL
dns_pipeline_probe_success{query="dnssec"} $OK_DNSSEC
EOF

[ "$OK_INTERNAL" -eq 1 ] && [ "$OK_EXTERNAL" -eq 1 ] && [ "$OK_DNSSEC" -eq 1 ] && exit 0 || exit 1
```

---

## 5. Web proxy probe — `web-probe.sh`

ADR §4.3 (lines 611-629).

```bash
#!/bin/sh
set -u

: "${WEB_PROXY_URL:?WEB_PROXY_URL is required}"
: "${WEB_TARGET_URL:?WEB_TARGET_URL is required}"
TIMEOUT="${WEB_TIMEOUT:-30}"
METRICS_DIR="${METRICS_DIR:-/var/lib/node_exporter/textfile_collector/probes}"
METRIC_FILE="${METRICS_DIR}/web_pipeline_probe.prom"

OUTFILE=$(mktemp)
trap 'rm -f "$OUTFILE"' EXIT

HTTP_CODE=$(curl -sS --proxy "$WEB_PROXY_URL" -m "$TIMEOUT" -o "$OUTFILE" -w '%{http_code}' \
  "$WEB_TARGET_URL" 2>/dev/null) || true

HTTP_CODE=${HTTP_CODE:-000}
SUCCESS=0

if [ "$HTTP_CODE" = "200" ] && [ -s "$OUTFILE" ]; then
  SUCCESS=1
fi

mkdir -p "$METRICS_DIR"
cat > "$METRIC_FILE" <<EOF
# HELP web_pipeline_probe_success Synthetic web proxy pipeline probe result
# TYPE web_pipeline_probe_success gauge
web_pipeline_probe_success{probe="mitm",pipeline="web"} $SUCCESS
EOF

[ "$SUCCESS" -eq 1 ] && exit 0 || exit 1
```

The `WEB_PROXY_URL` value is the full MITM proxy endpoint, e.g. `http://{{ infra_network_ip_proxy_mitm }}:{{ infra_port_proxy_mitm_adblock_container }}`.

---

## 6. VPN/egress probe — `vpn-probe.sh`

ADR §4.4 (lines 630-653).

```bash
#!/bin/sh
set -u

: "${HOST_PUBLIC_IP:?HOST_PUBLIC_IP is required}"
: "${NORDVPN_SOCKS5:?NORDVPN_SOCKS5 is required}"
: "${TOR_SOCKS5_HOSTNAME:?TOR_SOCKS5_HOSTNAME is required}"
TIMEOUT="${VPN_TIMEOUT:-30}"
METRICS_DIR="${METRICS_DIR:-/var/lib/node_exporter/textfile_collector/probes}"
METRIC_FILE="${METRICS_DIR}/vpn_egress_probe.prom"

# NordVPN — exit IP must not be the host's public IP
NORD_IP=$(curl -sS --socks5 "$NORDVPN_SOCKS5" -m "$TIMEOUT" \
  https://api.ipify.org 2>/dev/null) || NORD_IP=""

NORD_OK=0
[ -n "$NORD_IP" ] && [ "$NORD_IP" != "$HOST_PUBLIC_IP" ] && NORD_OK=1

# Tor — check.torproject.org returns JSON with IsTor: true
TOR_JSON=$(curl -sS --socks5-hostname "$TOR_SOCKS5_HOSTNAME" -m "$TIMEOUT" \
  https://check.torproject.org/api/ip 2>/dev/null) || TOR_JSON=""

TOR_OK=0
if [ -n "$TOR_JSON" ]; then
  [ "$(echo "$TOR_JSON" | jq -r '.IsTor // false' 2>/dev/null)" = "true" ] && TOR_OK=1
fi

# Tailscale — requires tailscale binary and access to the tailscaled socket
TAIL_OK=0
if command -v tailscale >/dev/null 2>&1; then
  tailscale status 2>/dev/null | grep -qi 'active' && TAIL_OK=1
fi

mkdir -p "$METRICS_DIR"
cat > "$METRIC_FILE" <<EOF
# HELP vpn_egress_probe_success Synthetic VPN/egress probe result
# TYPE vpn_egress_probe_success gauge
vpn_egress_probe_success{egress="nordvpn"} $NORD_OK
vpn_egress_probe_success{egress="tor"} $TOR_OK
vpn_egress_probe_success{egress="tailscale"} $TAIL_OK
EOF

[ "$NORD_OK" -eq 1 ] && [ "$TOR_OK" -eq 1 ] && [ "$TAIL_OK" -eq 1 ] && exit 0 || exit 1
```

**Notes:**
- `api.ipify.org` is a simple public IP echo service.
- `check.torproject.org/api/ip` returns `{"IsTor":true}` for a working Tor exit.
- The Tailscale check assumes the `tailscale` binary is installed and the container has the Tailscale socket mounted (`/var/run/tailscale/tailscaled.sock` on the host) or is running with `network_mode: host`.

---

## 7. Pushgateway vs textfile collector

### Pushgateway pattern

Probes push metrics to `prom/pushgateway`, Prometheus scrapes the Pushgateway.

**Pros:**
- Natural fit for very short-lived or one-shot jobs.
- Jobs do not need to live during a Prometheus scrape interval.

**Cons:**
- Pushgateway will keep exposing a series forever unless it is explicitly deleted via the API; stale data is the main failure mode.
- No per-probe `up` metric; the only `up` metric is for the Pushgateway itself.
- Becomes a single point of failure and a bottleneck for many clients.

Source: https://prometheus.io/docs/practices/pushing/, https://github.com/prometheus/pushgateway.

### node_exporter textfile collector pattern

Probes write `*.prom` files to a directory read by `node_exporter`.

**Pros:**
- No extra container — `node_exporter` is already planned in the monitoring stack (ADR §1).
- Prometheus gets real `up`, `node_textfile_mtime_seconds` and normal staleness behavior.
- Simpler to debug: `cat` the `.prom` file and check `node_exporter` output.

**Cons:**
- Requires a shared volume (bind mount) between the probe cron container and `node_exporter`.
- Timestamps inside the textfile format are not supported; rely on `node_textfile_mtime_seconds` to detect stale files.

Source: https://github.com/prometheus/node_exporter/blob/master/README.md#textfile-collector.

### Recommendation for infrahub

**Use the textfile collector.** The monitoring stack already deploys `node_exporter`, and the ADR probes run on a scheduled interval, so there is no ephemeral "job finished before scrape" problem.

**Directory structure:**

```
/var/lib/node_exporter/textfile_collector/
└── probes/
    ├── ai_litellm_probe.prom
    ├── ai_omnigent_probe.prom
    ├── dns_pipeline_probe.prom
    ├── web_pipeline_probe.prom
    └── vpn_egress_probe.prom
```

`node_exporter` must be started with:

```text
--collector.textfile.directory=/var/lib/node_exporter/textfile_collector
```

Prometheus alert for stale probe files:

```yaml
- alert: SyntheticProbeFileStale
  expr: time() - node_textfile_mtime_seconds{file="/var/lib/node_exporter/textfile_collector/probes/ai_litellm_probe.prom"} > 600
  for: 2m
  labels:
    severity: warning
    pipeline: ai
```

---

## 8. Probe container design

### 8.1 Dockerfile

```dockerfile
FROM alpine:3.20

RUN apk add --no-cache \
    curl \
    jq \
    bind-tools \
    dcron \
    tailscale

WORKDIR /opt/probes

COPY ai-probe.sh ai-omnigent-probe.sh dns-probe.sh web-probe.sh vpn-probe.sh /opt/probes/
COPY crontab /etc/crontabs/root

RUN chmod +x /opt/probes/*.sh

CMD ["crond", "-f", "-l", "2"]
```

### 8.2 `crontab`

```text
*/5 * * * * /opt/probes/ai-probe.sh
*/5 * * * * /opt/probes/ai-omnigent-probe.sh
*/2 * * * * /opt/probes/dns-probe.sh
*/5 * * * * /opt/probes/web-probe.sh
*/5 * * * * /opt/probes/vpn-probe.sh
```

### 8.3 Ansible task (community.docker.docker_container)

```yaml
- name: Deploy synthetic probe cron container
  community.docker.docker_container:
    name: "{{ infra_name_monitoring_synthetic_probes }}"
    image: "{{ infra_image_synthetic_probes }}:{{ infra_tag_synthetic_probes }}"
    command: ["crond", "-f", "-l", "2"]
    state: started
    restart_policy: unless-stopped
    networks:
      - name: "{{ infra_network_monitoring }}"
    env:
      LITELLM_ENDPOINT: "https://{{ infra_domain_ai_litellm_api }}/v1/chat/completions"
      LITELLM_API_KEY: "{{ vault_litellm_synthetic_probe_key }}"
      OMNIGENT_ENDPOINT: "https://{{ infra_domain_ai_omnigent }}"
      OMNIGENT_API_KEY: "{{ vault_omnigent_synthetic_probe_key }}"
      DNS_INTERNAL_DOMAIN: "{{ infra_domain_base }}"
      WEB_PROXY_URL: "http://{{ infra_network_ip_proxy_mitm }}:{{ infra_port_proxy_mitm_adblock_container }}"
      WEB_TARGET_URL: "http://example.com"
      HOST_PUBLIC_IP: "{{ host_public_ip }}"
      NORDVPN_SOCKS5: "{{ infra_network_ip_vpn_nordvpn }}:{{ infra_port_vpn_nordvpn_socks_container }}"
      TOR_SOCKS5_HOSTNAME: "{{ infra_network_ip_dns_tor_proxy }}:{{ infra_port_proxy_tor_socks5_container }}"
      METRICS_DIR: "/var/lib/node_exporter/textfile_collector/probes"
    volumes:
      - "{{ monitoring_synthetic_probes_host_dir }}:/opt/probes:ro"
      - "{{ monitoring_textfile_collector_host_dir }}:/var/lib/node_exporter/textfile_collector/probes"
    capabilities: []
```

Make sure `node_exporter` is started with `--collector.textfile.directory={{ monitoring_textfile_collector_host_dir }}` and that the host directory is writable by the probe container and readable by `node_exporter`.

### 8.4 Role files (ADR §6)

Per ADR lines 690-695:

```
shared/active/02-config/ansible/roles/monitoring-synthetic-probes/
├── templates/
│   ├── ai-probe.sh.j2
│   ├── ai-omnigent-probe.sh.j2
│   ├── dns-probe.sh.j2
│   ├── web-probe.sh.j2
│   └── vpn-probe.sh.j2
├── files/crontab
├── tasks/main.yml
└── defaults/main.yml
```

---

## 9. Recommendations

1. **Use the textfile collector, not Pushgateway, for the ADR synthetic probes.** It reuses `node_exporter`, avoids stale series and is simpler to operate.
2. **Implement each ADR probe as a small POSIX shell script** using `curl`, `jq`, `dig` and `tailscale`. These are the only tools that cover all four probe specs.
3. **blackbox_exporter is optional** — deploy it for simple TCP/HTTP per-node health checks, but do **not** try to implement the four synthetic probes with it.
4. **Mount the same host directory** into the probe cron container and into `node_exporter` for the textfile collector.
5. **Add a staleness alert** on `node_textfile_mtime_seconds` so a failed cron container or stale file is caught.
6. **Keep all secrets in the client vault** (`vault_litellm_synthetic_probe_key`, `vault_omnigent_synthetic_probe_key`) and pass them as `env:` to the container — never hardcode or commit them.

---

## Sources

- ADR-202608270001, §4 Synthetic Probes, lines 465-653: `/Users/micro/p/gh/levonk/infrahub/shared/active/08-docs/adr/adr-202608270001-pipeline-observability-strategy.md`
- prometheus/blackbox_exporter README and configuration: https://github.com/prometheus/blackbox_exporter, https://github.com/prometheus/blackbox_exporter/blob/master/CONFIGURATION.md
- Prometheus multi-target exporter guide: https://prometheus.io/docs/guides/multi-target-exporter/
- Prometheus Pushgateway best practices: https://prometheus.io/docs/practices/pushing/
- Prometheus Pushgateway repo: https://github.com/prometheus/pushgateway
- node_exporter textfile collector: https://github.com/prometheus/node_exporter/blob/master/README.md
- Omnigent / LiteLLM endpoint definitions: ADR §4.1, lines 501-570.
