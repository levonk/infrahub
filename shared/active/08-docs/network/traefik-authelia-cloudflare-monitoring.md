# Traefik Authelia Cloudflare - Monitoring and Logging

## Overview

This document describes the monitoring and logging configuration for the Traefik proxy stack with Authelia, CrowdSec, and Cloudflare integration.

## Log Locations and Formats

### Traefik

**Log Locations:**
- Application logs: `/var/log/traefik/traefik.log`
- Access logs: `/var/log/traefik/access.log`
- Container logs: Docker JSON format via `docker logs traefik`

**Log Format:** JSON
```json
{
  "time": "2026-06-20T12:00:00Z",
  "level": "INFO",
  "msg": "Configuration loaded"
}
```

**Log Rotation:**
- Configured via logrotate: `/etc/logrotate.d/traefik`
- Retention: 30 days (configurable via `proxy_traefik_log_retention_days`)
- Compression: Enabled
- Max file size: 10MB
- Max files: 5

### Authelia

**Log Locations:**
- Application logs: `/var/log/authelia/authelia.log`
- Container logs: Docker JSON format via `docker logs proxy-authelia`

**Log Format:** JSON
```json
{
  "level": "info",
  "time": "2026-06-20T12:00:00Z",
  "msg": "Authentication successful",
  "user": "admin"
}
```

**Log Rotation:**
- Configured via logrotate: `/etc/logrotate.d/authelia`
- Retention: 30 days (configurable via `proxy_authelia_log_retention_days`)
- Compression: Enabled
- Max file size: 10MB
- Max files: 5

### CrowdSec

**Log Locations:**
- Application logs: `/var/log/crowdsec/crowdsec.log`
- Container logs: Docker JSON format via `docker logs crowdsec`
- Bouncer logs: `/var/log/crowdsec-bouncer.log`

**Log Format:** JSON
```json
{
  "level": "info",
  "time": "2026-06-20T12:00:00Z",
  "msg": "Decision received",
  "ip": "192.168.1.1",
  "action": "ban"
}
```

**Log Rotation:**
- Configured via logrotate: `/etc/logrotate.d/crowdsec`
- Retention: 30 days (configurable via `security_crowdsec_log_retention_days`)
- Compression: Enabled
- Max file size: 10MB
- Max files: 5

## Metrics Endpoints

### Traefik Metrics

**Endpoint:** `http://<host>:8883/metrics`
**Format:** Prometheus
**Access:** Internal network only (traefik-network)

**Available Metrics:**
- `traefik_entrypoint_requests_total` - Total requests per entrypoint
- `traefik_entrypoint_request_duration_seconds` - Request duration histogram
- `traefik_service_requests_total` - Total requests per service
- `traefik_service_request_duration_seconds` - Service request duration
- `traefik_service_server_up` - Server availability

### Authelia Metrics

**Endpoint:** `http://<host>:9092/metrics`
**Format:** Prometheus
**Access:** Internal network only (proxy-network)

**Available Metrics:**
- `authelia_request_duration_seconds` - Request duration histogram
- `authelia_requests_total` - Total requests
- `authelia_authentication_success_total` - Successful authentications
- `authelia_authentication_failure_total` - Failed authentications

### CrowdSec Metrics

**Endpoint:** `http://<host>:6060/metrics`
**Format:** Prometheus
**Access:** Internal network only (traefik-network)

**Available Metrics:**
- `crowdsec_decisions_total` - Total security decisions
- `crowdsec_decisions_by_type` - Decisions by type (ban, captcha, etc.)
- `crowdsec_alerts_total` - Total security alerts
- `crowdsec_bouncer_decisions_total` - Bouncer decisions

## Log Aggregation

### Current Configuration

The proxy stack uses Docker's JSON logging driver with local log rotation. No centralized log aggregation is currently configured.

### Log Shipping (Future)

For centralized logging, configure the following:
1. **Fluentd/Fluent Bit:** Deploy as a sidecar container to collect logs
2. **Elasticsearch/Opensearch:** Central log storage
3. **Grafana Loki:** Lightweight log aggregation
4. **CloudWatch Logs:** AWS integration
5. **Azure Monitor:** Azure integration

## Monitoring Dashboards

### Recommended Dashboards

1. **Traefik Dashboard:**
   - Request rate by entrypoint
   - Response time percentiles
   - Error rate by service
   - SSL certificate status

2. **Authelia Dashboard:**
   - Authentication success/failure rate
   - User activity
   - Session statistics
   - 2FA usage

3. **CrowdSec Dashboard:**
   - Security decisions by type
   - Blocked IPs by country
   - Alert trends
   - Bouncer performance

### Dashboard Implementation

For dashboard implementation, consider:
- **Grafana:** Open-source visualization
- **Prometheus:** Metrics collection
- **Alertmanager:** Alert routing and management

## Alert Configuration

### Critical Security Events

Configure alerts for:
1. **CrowdSec:**
   - High rate of security decisions (>100/minute)
   - Critical severity alerts
   - Bouncer failures

2. **Authelia:**
   - High authentication failure rate (>10%)
   - Brute force detection
   - 2FA failures

3. **Traefik:**
   - High error rate (>5%)
   - SSL certificate expiration (<7 days)
   - Service downtime

### Alert Channels

Configure alert delivery via:
- Email (SMTP)
- Slack webhooks
- Telegram bots
- PagerDuty integration
- SMS notifications

## Log Security

### Access Control

- Log files: `root:root` with `0644` permissions
- Container logs: Accessible via Docker API (requires root)
- Metrics endpoints: Internal network only

### Sensitive Data

**Dropped from logs:**
- Authorization headers (Traefik)
- Passwords and tokens (Authelia)
- API keys (CrowdSec)

**Retention:**
- Logs retained for 30 days (configurable)
- Compressed after rotation
- Secure deletion after retention period

## Troubleshooting

### Log Issues

**No logs appearing:**
1. Check container is running: `docker ps`
2. Check log driver: `docker inspect <container> | grep LogDriver`
3. Check disk space: `df -h /var/log`
4. Check logrotate configuration: `cat /etc/logrotate.d/<service>`

**Logs not rotating:**
1. Check logrotate status: `logrotate -d /etc/logrotate.d/<service>`
2. Check logrotate cron: `systemctl status logrotate`
3. Check file permissions: `ls -la /var/log/<service>`

### Metrics Issues

**Metrics endpoint not accessible:**
1. Check container is running: `docker ps`
2. Check port mapping: `docker inspect <container> | grep PublishedPorts`
3. Check network connectivity: `curl http://<host>:<port>/metrics`
4. Check metrics configuration in service config

**No metrics data:**
1. Check metrics are enabled in configuration
2. Check service health: `curl http://<host>:<port>/health`
3. Check Prometheus scraping configuration
4. Check firewall rules

## Configuration Variables

All monitoring and logging configuration is variable-driven per AGENTS.md:

### Traefik
- `proxy_traefik_log_level` - Log level (INFO, DEBUG, ERROR)
- `proxy_traefik_log_format` - Log format (json, text)
- `proxy_traefik_log_max_size` - Max log file size (10m)
- `proxy_traefik_log_max_file` - Max log files (5)
- `proxy_traefik_log_retention_days` - Log retention (30)
- `proxy_traefik_metrics_enabled` - Enable metrics (true)
- `proxy_traefik_metrics_port` - Metrics port (8883)

### Authelia
- `proxy_authelia_log_level` - Log level (info, debug, error)
- `proxy_authelia_log_format` - Log format (json, text)
- `proxy_authelia_log_max_size` - Max log file size (10m)
- `proxy_authelia_log_max_file` - Max log files (5)
- `proxy_authelia_log_retention_days` - Log retention (30)
- `proxy_authelia_metrics_enabled` - Enable metrics (true)
- `proxy_authelia_metrics_port` - Metrics port (9092)

### CrowdSec
- `security_crowdsec_log_level` - Log level (info, debug, error)
- `security_crowdsec_log_format` - Log format (json, text)
- `security_crowdsec_log_max_size` - Max log file size (10m)
- `security_crowdsec_log_max_file` - Max log files (5)
- `security_crowdsec_log_retention_days` - Log retention (30)
- `security_crowdsec_prometheus_enabled` - Enable metrics (true)
- `security_crowdsec_prometheus_port` - Metrics port (6060)

## References

- AGENTS.md: `~/p/gh/levonk/infrahub/AGENTS.md`
- Ansible AGENTS.md: `~/p/gh/levonk/infrahub/shared/active/02-config/ansible/AGENTS.md`
- PRD: `~/p/gh/levonk/infrahub/shared/active/08-docs/reqs/2026/20260620-traefik-authelia-cloudflare.md`
