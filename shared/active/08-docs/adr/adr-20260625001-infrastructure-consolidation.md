# ADR-20260625001: Infrastructure Consolidation Strategy

## Status
Accepted

## Context
The infrahub project has experienced configuration sprawl with infrastructure topology (IP addresses, ports, domain names, storage paths) scattered across multiple variable files. This has led to:

1. **Port Collisions**: No single source of truth for port allocations across services
2. **IP Address Conflicts**: Network subnets and IP assignments defined in multiple places
3. **Domain Name Fragmentation**: DNS records and domain names scattered across playbooks and variable files
4. **Change Management Difficulty**: No easy way to audit infrastructure topology changes
5. **Inconsistent Naming**: Variable naming conventions vary across files and services

The successful implementation of ADR-20260624001 (Hybrid Sensitive Information Storage) demonstrated the value of consolidating related configuration into centralized files with variable references. The same pattern should be applied to infrastructure topology.

## Decision
Implement a hybrid infrastructure consolidation strategy following the same pattern as ADR-20260624001:

### Shared Infrastructure Schemas
**Location**: `shared/active/02-config/ansible/infrastructure/`

Contains infrastructure variable schemas with sensible defaults:
- `networks.yml` - Network topology (subnets, gateways, network names, IP allocations)
- `ports.yml` - Port allocations (host/container ports by service)
- `domains.yml` - Domain names, DNS records, and hostnames
- `storage.yml` - Storage paths, volumes, and container mounts

### Client-Specific Infrastructure Values
**Location**: `levonk/active/02-config/ansible/infrastructure/`

Contains client-specific infrastructure value overrides:
- Same file structure as shared schemas
- Overrides shared defaults where needed
- Client-specific network topology, port assignments, domain names

### Variable Naming Convention
**Pattern**: `infra_{CATEGORY}_{SERVICE}_{CONTEXT}_{ATTRIBUTE}`

**Categories**:
- `network` - IP addresses, subnets, gateways, network names
- `port` - Host and container port assignments
- `domain` - Domain names, DNS records, hostnames
- `storage` - Volume paths, mount points, storage quotas

**Examples**:
```yaml
infra_network_vpn_nordvpn_subnet: "172.28.0.0/16"
infra_port_forge_host_http: "8083"
infra_domain_ai_dashboard_web: "ai-dashboard.levonk.com"
infra_storage_vault_path: "/opt/localnet/config/vault"
```

### Usage Pattern
1. Define schema in shared directory with defaults
2. Override client-specific values in client directory
3. Reference consolidated variables in existing configuration files
4. Single source of truth for infrastructure topology

## Consequences

### Positive
1. **No Collisions**: Single source of truth prevents port/IP conflicts
2. **Easy Auditing**: Complete infrastructure topology visible in one place
3. **Client Isolation**: Shared schemas with client-specific values
4. **Consistent Naming**: Standardized variable naming across all services
5. **Change Management**: Easy to see impact of infrastructure changes
6. **ADR Compliance**: Follows proven hybrid storage pattern from ADR-20260624001

### Negative
1. **Migration Effort**: Existing variable files need updates to reference consolidated variables
2. **Learning Curve**: Team needs to learn new variable naming convention
3. **File Complexity**: Infrastructure files may become large (manageable with categorization)

### Risks
1. **Variable Name Conflicts**: New naming convention may conflict with existing variables
   - **Mitigation**: Use `infra_` prefix to avoid conflicts with existing variables
2. **Migration Errors**: Incomplete migration may leave hardcoded values
   - **Mitigation**: Audit existing files for hardcoded values after migration
3. **Performance**: Additional variable files may slow Ansible execution
   - **Mitigation**: Minimal impact - Ansible already loads multiple variable files

## Implementation Plan

### Phase 1: Schema Creation
- [x] Create shared infrastructure schema files
- [x] Create client infrastructure value files
- [x] Document variable naming convention

### Phase 2: Migration
- [x] Update cloud_servers.yml to reference infrastructure variables
- [x] Update oci-cloud-server.yml host_vars to reference infrastructure variables
- [ ] Update remaining variable files (localnet_hosts.yml, isolation_vms.yml)
- [ ] Update playbook variables to reference infrastructure variables
- [ ] Update docker-compose files to use infrastructure variables

### Phase 3: Validation
- [ ] Verify no port collisions across all services
- [ ] Verify no IP subnet conflicts
- [ ] Verify domain name consistency
- [ ] Test Ansible playbook execution with new variables

### Phase 4: Documentation
- [x] Create ADR document
- [ ] Update AGENTS.md with infrastructure consolidation guidelines
- [ ] Update playbook documentation with new variable references

## ADR Compliance

This ADR follows and extends ADR-20260624001 principles:
- **Shared Path Clean**: Shared directory contains schemas and defaults (no client secrets)
- **Client-Specific Values**: Client directory contains client-specific infrastructure values
- **Variable References**: Configuration files reference consolidated variables
- **Single Source of Truth**: Infrastructure topology centralized in dedicated files

## References
- ADR-20260624001: Hybrid Sensitive Information Storage Strategy
- Ansible Variable Precedence Rules
- Infrastructure as Code Best Practices

## Revision History
- 2026-06-25: Initial ADR creation - Infrastructure consolidation strategy accepted