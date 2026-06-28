# Infrastructure Consolidation Schema

## Purpose
Centralized infrastructure topology following ADR-20260624001 hybrid storage pattern:
- **Shared directory**: Variable schemas with sensible defaults
- **Client directory**: Client-specific infrastructure values
- **Single source of truth**: No more port collisions or scattered IP assignments

## File Structure

### Shared Schema Files (`shared/active/02-config/ansible/infrastructure/`)
- `networks.yml` - Network topology (subnets, gateways, network names)
- `ports.yml` - Port allocations (host/container ports by service)
- `domains.yml` - Domain names and DNS records
- `storage.yml` - Storage paths, volumes, and container mounts

### Client Value Files (`levonk/active/02-config/ansible/infrastructure/`)
- Same structure as shared, but with client-specific values
- Overrides shared defaults where needed
- Client-specific infrastructure topology

## Variable Naming Convention

**Pattern:** `infra_{CATEGORY}_{SERVICE}_{CONTEXT}_{ATTRIBUTE}`

**Categories:**
- `network` - IP addresses, subnets, gateways, network names
- `port` - Host and container port assignments
- `domain` - Domain names, DNS records, hostnames
- `storage` - Volume paths, mount points, storage quotas

**Examples:**
```yaml
infra_network_vpn_nordvpn_subnet: "172.28.0.0/16"
infra_port_forge_host_http: "8083"
infra_domain_ai_dashboard_web: "ai-dashboard.levonk.com"
infra_storage_vault_path: "/opt/localnet/config/vault"
```

## Usage Pattern

### 1. Define Schema in Shared Directory
```yaml
# shared/active/02-config/ansible/infrastructure/ports.yml
infra_port_ssh_host: "22"
infra_port_ssh_container: "22"
infra_port_http_host: "80"
infra_port_http_container: "80"
```

### 2. Override in Client Directory
```yaml
# levonk/active/02-config/ansible/infrastructure/ports.yml
infra_port_ssh_host: "2222"  # Client-specific override
```

### 3. Reference in Playbooks
```yaml
# group_vars/all.yml or host_vars/*.yml
ssh_host_port: "{{ infra_port_ssh_host }}"
```

## Benefits

1. **No Collisions**: Single source of truth for all infrastructure resources
2. **Easy Auditing**: See all network topology in one place
3. **Client Isolation**: Shared schemas, client-specific values
4. **Consistent Naming**: Standardized variable naming across all services
5. **Change Management**: Easy to see impact of infrastructure changes

## Migration Path

1. Create schema files in shared/ directory
2. Create client-specific value files in levonk/ directory  
3. Update existing variable files to reference consolidated variables
4. Validate no port/IP collisions
5. Update documentation

## ADR Compliance

This follows ADR-20260624001 hybrid storage principles:
- Shared path contains schemas and defaults (no client secrets)
- Client path contains client-specific infrastructure values
- Variable references in configuration files
- Single source of truth for infrastructure topology