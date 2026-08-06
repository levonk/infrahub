# n8n Observability — Dashboard Research

Source: https://github.com/n8n-io/n8n-observability
Date: 2026-08-05

## Stack

Prometheus + Grafana (metrics only; no Loki/Alertmanager).

## Services

| Service | Container | Port | Purpose |
|---------|-----------|------|---------|
| Prometheus | n8n-prometheus | 9090 | Metrics scraping + storage |
| Grafana | n8n-grafana | 3000 | Dashboard visualization |

## Dashboards

### 1. n8n Webhook Executions (HIGH priority)
- Execution counts, success/failure rates, latency (p50/p95/p99)
- Per-workflow breakdown with clickable links to n8n UI
- Required n8n env: `N8N_METRICS=true`, `N8N_METRICS_INCLUDE_WEBHOOK_METRICS=true`, `N8N_METRICS_INCLUDE_WORKFLOW_INFO=true`

### 2. n8n Form Executions (MEDIUM priority)
- Form submission counts, success/failure rates
- Required n8n env: `N8N_METRICS=true`, `N8N_METRICS_INCLUDE_FORM_METRICS=true`, `N8N_METRICS_INCLUDE_WORKFLOW_INFO=true`

### 3. n8n Durable Scheduler (LOW priority — queue mode only)
- Queue depth, scheduling lag, dispatch throughput, retries, dead-letters
- Required n8n env: `N8N_METRICS=true`, `N8N_METRICS_INCLUDE_SCHEDULER_METRICS=true`

## n8n Metrics Environment Variables

```bash
N8N_METRICS=true
N8N_METRICS_INCLUDE_WEBHOOK_METRICS=true
N8N_METRICS_INCLUDE_FORM_METRICS=true
N8N_METRICS_INCLUDE_WORKFLOW_INFO=true
N8N_METRICS_INCLUDE_SCHEDULER_METRICS=true  # queue mode only
```

## Prometheus Scrape Config

```yaml
global:
  scrape_interval: 15s
scrape_configs:
  - job_name: n8n
    static_configs:
      - targets:
          - <n8n-container-name>:5678  # same Docker network
    metrics_path: /metrics
```

## Grafana Provisioning

The repo includes:
- Datasource provisioning (auto-configures Prometheus)
- Dashboard provisioning (auto-loads n8n dashboards)
- Custom entrypoint.sh for live-reloading
- Optional Slack alerting

## Security

`/metrics` endpoint should NOT be exposed publicly — only accessible by Prometheus within trusted network.
