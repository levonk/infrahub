# isolation-vm-docker

Install and configure Docker inside the Isolation VM for AI agent containers.

## Role Variables

### Installation Configuration

- `isolation_vm_docker_version` - Docker version to install (default: empty, installs latest)
- `isolation_vm_docker_install_method` - Installation method: "repo" or "package" (default: "repo")
- `isolation_vm_docker_skip_installation` - Skip Docker installation (default: false)

### User & Groups

- `isolation_vm_docker_user` - Non-root user to add to docker group (default: `{{ isolation_vm_user | default('cuser') }}`)
- `isolation_vm_docker_group` - Docker group name (default: "docker")
- `isolation_vm_docker_gid` - Docker group GID (default: empty)

### Daemon Configuration

- `isolation_vm_docker_daemon_config_path` - Path to daemon.json (default: "/etc/docker/daemon.json")
- `isolation_vm_docker_daemon_config_owner` - daemon.json owner (default: "root")
- `isolation_vm_docker_daemon_config_group` - daemon.json group (default: "root")
- `isolation_vm_docker_daemon_config_mode` - daemon.json mode (default: "0644")
- `isolation_vm_docker_log_driver` - Docker log driver (default: "json-file")
- `isolation_vm_docker_log_opts` - Log rotation options (default: max-size: "10m", max-file: "3")
- `isolation_vm_docker_live_restore` - Enable live restore (default: true)
- `isolation_vm_docker_storage_driver` - Storage driver (default: "overlay2")
- `isolation_vm_docker_extra_daemon_config` - Additional daemon.json settings (default: {})

### Service Configuration

- `isolation_vm_docker_service_name` - Docker service name (default: "docker")

### Verification

- `isolation_vm_docker_verify_install` - Run hello-world test (default: true)

## Dependencies

None

## Example Playbook

```yaml
- hosts: isolation_vms
  become: true
  roles:
    - role: isolation-vm-docker
      vars:
        isolation_vm_docker_user: "cuser"
        isolation_vm_docker_log_opts:
          max-size: "50m"
          max-file: "5"
```

## Features

- Installs Docker CE from official repository
- Configures Docker daemon with log rotation
- Adds non-root user to docker group
- Enables and starts Docker service
- Verifies installation with hello-world test
- Variable-driven configuration per AGENTS.md

## Compliance

- Follows container guidelines from `shared/active/03-container/AGENTS.md`
- All configuration is variable-driven
- No hardcoded IPs, ports, or values
