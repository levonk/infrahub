# proxy-authelia

Ansible role to deploy [Authelia](https://www.authelia.com/) as a Docker container for Single Sign-On (SSO).

## Requirements

- Docker Engine (role `docker-engine`)
- `community.docker` Ansible collection

## Role Variables

See `defaults/main.yml` for full list. Key variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `proxy_authelia_enabled` | `true` | Enable/disable Authelia deployment |
| `proxy_authelia_web_host_port` | `9091` | Host port for Authelia web UI |
| `proxy_authelia_web_container_port` | `9091` | Container port for Authelia web UI |
| `proxy_authelia_admin_user` | `admin` | Default admin username |
| `proxy_authelia_admin_password` | `change-me-in-vault` | **Must be overridden via vault** |
| `proxy_authelia_jwt_secret` | `change-me-in-vault` | **Must be overridden via vault** |
| `proxy_authelia_session_secret` | `change-me-in-vault` | **Must be overridden via vault** |
| `proxy_authelia_storage_encryption_key` | `change-me-in-vault` | **Must be overridden via vault** |
| `proxy_authelia_redis_enabled` | `true` | Enable Redis session sidecar |
| `proxy_authelia_redis_host_port` | `6379` | Host port for Redis |
| `proxy_authelia_redis_password` | `change-me-in-vault` | **Must be overridden via vault** |

## Dependencies

None.

## Example Playbook

```yaml
- hosts: proxy_servers
  become: true
  roles:
    - role: proxy-authelia
      vars:
        proxy_authelia_admin_password: "{{ vault_authelia_admin_password }}"
        proxy_authelia_jwt_secret: "{{ vault_authelia_jwt_secret }}"
        proxy_authelia_session_secret: "{{ vault_authelia_session_secret }}"
        proxy_authelia_storage_encryption_key: "{{ vault_authelia_storage_key }}"
```

## Testing

```bash
ansible-playbook -i localhost, -c local tests/test.yml --check --diff
```

## License

MIT
