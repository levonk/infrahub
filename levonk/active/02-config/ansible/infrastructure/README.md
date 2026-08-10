# Levonk Client Infrastructure Values

## Purpose
Client-specific infrastructure values for the levonk client.
Overrides shared defaults from `shared/active/02-config/ansible/infrastructure/`

## Client-Specific Overrides

This file contains levonk-specific infrastructure topology that differs from shared defaults:
- Custom network subnets for levonk's multi-exit-node architecture
- Custom port allocations for levonk's AI pipeline
- Custom domain names for levonk's services
- Custom storage paths for levonk's deployment

## Integration

These values are loaded by Ansible playbooks and override the shared schema defaults:
```yaml
# In playbook vars files
vpn_nordvpn_subnet: "{{ infra_network_vpn_nordvpn_subnet }}"
forge_host_port: "{{ infra_port_ai_forge_host }}"
ai_dashboard_domain: "{{ infra_domain_ai_dashboard_web }}"
```

## ADR Compliance

Follows ADR-20260624001:
- Client-specific values in client submodule (levonk/)
- Shared schemas in shared/ directory
- Variable references in configuration files
- Single source of truth for infrastructure topology