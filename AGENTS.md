# Agent Guidelines for localnet

## IP and Port Configuration Rules

### CRITICAL: All IP Addresses and Ports Must Be Variables

**ABSOLUTELY FORBIDDEN**: Hardcoded IP addresses and port numbers in configuration files, especially in Ansible tasks and Docker Compose files.

**REQUIRED**: All IP addresses and port numbers must be defined as variables.

#### Examples of Violations

**❌ FORBIDDEN - Hardcoded ports in Ansible tasks:**
```yaml
ports:
  - "8888:8888/tcp"
  - "8388:8388/tcp"
  - "8388:8388/udp"
  - "6881:6881/udp"
```

**❌ FORBIDDEN - Hardcoded container ports:**
```yaml
ports:
  - "{{ proxy_http_transparent_port }}:80/tcp"
  - "{{ proxy_https_transparent_port }}:443/tcp"
  - "{{ proxy_envoy_internal_host_port }}:3129/tcp"
  - "{{ proxy_envoy_admin_host_port }}:9901/tcp"
```

**✅ REQUIRED - All ports as variables:**
```yaml
ports:
  - "{{ proxy_http_transparent_port }}:{{ proxy_http_container_port }}/tcp"
  - "{{ proxy_https_transparent_port }}:{{ proxy_https_container_port }}/tcp"
  - "{{ proxy_envoy_internal_host_port }}:{{ proxy_envoy_internal_container_port }}/tcp"
  - "{{ proxy_envoy_admin_host_port }}:{{ proxy_envoy_admin_container_port }}/tcp"
```

#### Examples of IP Address Violations

**❌ FORBIDDEN - Hardcoded IP addresses:**
```yaml
ansible_host: 127.0.0.1
docker_network_gateway: "172.26.0.1"
bindaddress: 0.0.0.0
```

**✅ REQUIRED - All IPs as variables:**
```yaml
ansible_host: "{{ ansible_host_ip }}"
docker_network_gateway: "{{ docker_network_gateway }}"
bindaddress: "{{ service_bind_address }}"
```

#### Rationale

- **Portability**: Variables allow easy deployment across different environments
- **Flexibility**: Changes can be made in one place (group_vars, .env files) without touching configuration files
- **Security**: Sensitive network topology details can be externalized
- **Maintainability**: Centralized configuration management

#### Enforcement

All new configuration must:
1. Define all ports as variables in `group_vars/all.yml` or service-specific `.env` files
2. Define all IP addresses as variables, including:
   - Network gateways and subnets
   - Service bind addresses (use variables instead of `0.0.0.0` or `127.0.0.1`)
   - Container IP assignments
3. Never hardcode port numbers in `ports:` sections (both host and container ports must be variables)
4. Never hardcode IP addresses in any configuration file

#### Current Violations to Fix

The following files contain hardcoded ports or IPs and need to be refactored:

**Ansible Tasks:**
- `shared/active/02-config/ansible/roles/vpn/tasks/main.yml` (lines 40-45)
- `shared/active/02-config/ansible/roles/proxy/tasks/main.yml` (lines 138-141 - container ports)

**Docker Compose Files:**
- `shared/active/03-container/services/vpn/docker-compose.vpn.yml` (lines 20-25)
- `shared/active/03-container/services/dns/adguard/docker-compose.adguard.yml` (lines 14-16)
- Various other docker-compose files with hardcoded ports

When working on localnet, always check for hardcoded IPs and ports before committing changes.
