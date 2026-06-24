# docker-engine

Install Docker Engine and the Docker Compose plugin, create a hardened `daemon.json`, and configure the Docker service.

## Requirements

- Ansible >= 2.15
- Target host: Debian 12 (bookworm) or Ubuntu 22.04/24.04
- Internet connectivity to download Docker packages

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `docker_engine_version` | `""` | Optional Docker version pin |
| `docker_engine_install_method` | `"repo"` | Installation method (`repo` or `package`) |
| `docker_engine_admin_user` | `{{ cloud_server_admin_user \| default('cuser') }}` | Admin username to add to docker group |
| `docker_engine_group` | `docker` | Docker group name |
| `docker_engine_gid` | `""` | Optional GID for docker group |
| `docker_engine_daemon_config_path` | `/etc/docker/daemon.json` | Path to daemon.json |
| `docker_engine_userns_remap` | `"default"` | Userns-remap setting (empty to disable) |
| `docker_engine_no_new_privileges` | `true` | Enable no-new-privileges |
| `docker_engine_live_restore` | `true` | Enable live-restore |
| `docker_engine_log_driver` | `json-file` | Log driver |
| `docker_engine_log_opts` | `{max-size: 10m, max-file: 3}` | Log options |
| `docker_engine_extra_daemon_config` | `{}` | Extra daemon.json key-value pairs |

## Dependencies

None.

## Example Playbook

```yaml
- hosts: cloud_servers
  become: true
  roles:
    - role: docker-engine
      vars:
        docker_engine_admin_user: "admin"
        docker_engine_userns_remap: "default"
        docker_engine_extra_daemon_config:
          "default-address-pools":
            - base: "172.30.0.0/16"
              size: 24
```

## License

MIT
