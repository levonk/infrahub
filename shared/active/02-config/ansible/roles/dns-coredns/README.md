# dns-coredns

Deploy [CoreDNS](https://coredns.io/) as a Docker container for cloud-server DNS resolution.

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `dns_coredns_image` | `coredns/coredns` | Container image |
| `dns_coredns_image_tag` | `latest` | Image tag |
| `dns_coredns_container_name` | `cloud-server-dns-coredns` | Container name |
| `dns_coredns_volume_name` | `dns-coredns-data` | Data volume name |
| `dns_coredns_network_name` | `cloud-server` | Docker network name |
| `dns_coredns_host_port` | `53` | Host DNS port |
| `dns_coredns_container_port` | `53` | Container DNS port |
| `dns_coredns_metrics_host_port` | `9153` | Host metrics/health port |
| `dns_coredns_metrics_container_port` | `9153` | Container metrics/health port |
| `dns_coredns_upstreams` | `['1.1.1.1', '1.0.0.1']` | Upstream DNS resolvers |
| `dns_coredns_local_zones` | `[]` | Local authoritative zones |
| `dns_coredns_cache_ttl_max` | `300` | Max cache TTL (seconds) |
| `dns_coredns_service_dir` | `/opt/cloud-server/services/dns/coredns` | Config directory |

## Cloud-Server Override Variables

Set these in `group_vars` or `host_vars` to override defaults:

| Variable | Description |
|----------|-------------|
| `cloud_server_coredns_image_tag` | Image tag override |
| `cloud_server_coredns_container_name` | Container name override |
| `cloud_server_dns_port` | Host DNS port |
| `cloud_server_dns_container_port` | Container DNS port |
| `cloud_server_dns_metrics_port` | Host metrics port |
| `cloud_server_dns_upstreams` | Upstream resolver list |
| `cloud_server_dns_local_zones` | Local zone definitions |

## Dependencies

- `docker-engine` role (must be installed on target host)

## Example Playbook

```yaml
- hosts: dns_servers
  become: true
  roles:
    - role: dns-coredns
```

## License

MIT
