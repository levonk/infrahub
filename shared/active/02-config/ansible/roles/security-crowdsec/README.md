# security-crowdsec

Deploy CrowdSec security engine and CrowdSec Bouncer for Traefik with IP-based threat protection, configurable ban durations, and variable-driven configuration per AGENTS.md guidelines.

## Requirements

- Ansible >= 2.15
- Target host: Debian 12 (bookworm) or Ubuntu 22.04/24.04
- Docker Engine installed (dependency: docker-engine role)
- Traefik deployed (for log acquisition and bouncer integration)
- Internet connectivity for CrowdSec collections and updates

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `security_crowdsec_enabled` | `true` | Enable CrowdSec deployment |
| `security_crowdsec_data_dir` | `/opt/crowdsec` | CrowdSec data directory |
| `security_crowdsec_container_name` | `crowdsec` | Docker container name |
| `security_crowdsec_image` | `crowdsecurity/crowdsec` | Docker image name |
| `security_crowdsec_image_tag` | `latest` | Docker image tag |
| `security_crowdsec_lapi_port` | `8080` | LAPI host port |
| `security_crowdsec_default_ban_duration` | `672h` | Default ban duration (28 days) |
| `security_crowdsec_bouncer_api_key` | `change-me-in-vault` | Bouncer API key (MUST use vault) |
| `security_crowdsec_traefik_container_name` | `traefik` | Traefik container name for log acquisition |

## Client Overrides

Override defaults in `group_vars/cloud_server.yml` or `host_vars/oci-cloud-server.yml`:

```yaml
security_crowdsec_bouncer_api_key: "{{ vault_crowdsec_bouncer_api_key }}"
security_crowdsec_default_ban_duration: "168h"  # 7 days instead of 28
security_crowdsec_severity_profiles_enabled: true
security_crowdsec_collections: "crowdsecurity/linux crowdsecurity/traefik"
```

## Security Configuration

### API Token Management (CRITICAL)

The bouncer API key **MUST** be stored in Ansible vault:

```bash
# Add to vault
ansible-vault encrypt_string --vault-password-file ~/.ansible/vault_password "your-api-key-here" --name 'vault_crowdsec_bouncer_api_key'
```

### Remediation Profiles

Default profile uses 672h (28 days) ban duration. Configure custom profiles:

```yaml
security_crowdsec_custom_profiles_enabled: true
security_crowdsec_custom_profiles:
  - name: strict
    duration: "720h"  # 30 days
    decision_type: ban
    scope: ip
    filters:
      - alert.reason like "ssh:brute-force"
      - alert.reason like "http:brute-force"
```

### Severity-Based Profiles

Enable automatic severity-based remediation:

```yaml
security_crowdsec_severity_profiles_enabled: true
security_crowdsec_critical_ban_duration: "720h"  # 30 days
security_crowdsec_high_ban_duration: "168h"  # 7 days
security_crowdsec_medium_ban_duration: "24h"
security_crowdsec_low_ban_duration: "4h"
```

## Dependencies

- `docker-engine` - Installs Docker Engine and Compose plugin
- `proxy-traefik` - Deploys Traefik (for log acquisition and network)

## Example Playbook

```yaml
- hosts: cloud_servers
  become: true
  roles:
    - role: security-crowdsec
      vars:
        security_crowdsec_bouncer_api_key: "{{ vault_crowdsec_bouncer_api_key }}"
        security_crowdsec_default_ban_duration: "168h"
        security_crowdsec_severity_profiles_enabled: true
```

## Log Acquisition

### Traefik Log Acquisition (Default)

Automatically configured to read Traefik container logs:

```yaml
security_crowdsec_traefik_log_acquisition_enabled: true
security_crowdsec_traefik_container_name: "traefik"
```

### System Log Acquisition (Optional)

Enable system log monitoring:

```yaml
security_crowdsec_system_log_acquisition_enabled: true
```

### Docker Log Acquisition (Optional)

Enable all container log monitoring:

```yaml
security_crowdsec_docker_log_acquisition_enabled: true
```

## Bouncer Configuration

### Traefik Bouncer

Default mode for Traefik integration:

```yaml
security_crowdsec_bouncer_mode: "traefik"
security_crowdsec_bouncer_daemon: true
security_crowdsec_bouncer_forward_headers: true
```

### Redis Cache (Optional)

Enable Redis caching for improved performance:

```yaml
security_crowdsec_bouncer_redis_enabled: true
security_crowdsec_bouncer_redis_host: "redis"
security_crowdsec_bouncer_redis_port: "6379"
security_crowdsec_bouncer_redis_password: "{{ vault_redis_password }}"
```

## Collections Configuration

CrowdSec collections define security scenarios and parsers:

```yaml
security_crowdsec_collections: "crowdsecurity/linux crowdsecurity/traefik crowdsecurity/http-cve crowdsecurity/whitelist-good-ips"
```

## Prometheus Metrics

Enable Prometheus metrics for monitoring:

```yaml
security_crowdsec_prometheus_enabled: true
security_crowdsec_prometheus_level: "full"
security_crowdsec_prometheus_port: "6060"
```

## Slack Notifications (Optional)

Configure Slack notifications for security events:

```yaml
security_crowdsec_slack_webhook_url: "{{ vault_slack_webhook_url }}"
security_crowdsec_slack_channel: "#security"
security_crowdsec_slack_username: "CrowdSec"
```

## Health Verification

Enable health checks during deployment:

```yaml
security_crowdsec_verify_health: true
```

## Security Guidelines

### Per AGENTS.md Requirements

- **All IPs and ports are variable-driven** - No hardcoded network values
- **API tokens in vault** - Never commit secrets to repository
- **Volume persistence** - SQLite database stored in Docker volume
- **Network integration** - Connected to Traefik network for bouncer communication

### Data Retention

- Ban database persists in Docker volume: `localnet-crowdsec-db-volume`
- Configuration persists in Docker volume: `localnet-crowdsec-config-volume`
- Logs rotated with max-size and max-file limits

### False Positive Management

- Configure custom remediation profiles for different threat levels
- Use severity-based profiles for graduated responses
- Monitor CrowdSec decisions via LAPI or Prometheus metrics

## Troubleshooting

### Check CrowdSec Status

```bash
docker exec crowdsec cscli metrics
docker exec crowdsec cscli decisions list
```

### Check Bouncer Status

```bash
docker logs crowdsec-bouncer
```

### Regenerate Bouncer Token

```bash
docker exec crowdsec cscli bouncers add traefik-bouncer
```

### View Acquisition Status

```bash
docker exec crowdsec cscli acqui list
```

## License

MIT
