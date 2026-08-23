---
story_id: "01-001"
story_title: "Infrastructure schemas + client values + DNS + catalog"
story_name: "infra-schemas"
prd_name: "hister-search-deploy"
prd_file: "internal-docs/feature/todo/hister-search-deploy/feat-202608222054-hister-search-deploy.md"
phase: 1
parallel_id: 1
branch: "feature/current/hister-search-deploy/story-01-001-infra-schemas"
status: "todo"
assignee: ""
reviewer: ""
dependencies: []
parallel_safe: true
modules: ["infrastructure", "dns", "catalog"]
priority: "MUST"
risk_level: "low"
tags: ["infra", "ansible", "yaml"]
due: "2026-08-22"
create-date: "2026-08-22"
update-date: "2026-08-22"
---

## Summary

Add Hister infrastructure variables to shared schemas (ports, domains, storage),
client-specific overrides in levonk (domain, DNS CNAME), and service catalog
entry with `source_repo`. This is the foundation that all subsequent stories
depend on.

## Sub-Tasks

- [ ] Add port variables to `shared/active/02-config/ansible/infrastructure/ports.yml`
- [ ] Add domain variable to `shared/active/02-config/ansible/infrastructure/domains.yml`
- [ ] Add storage variable to `shared/active/02-config/ansible/infrastructure/storage.yml`
- [ ] Add client domain override to `levonk/active/02-config/ansible/infrastructure/domains.yml`
- [ ] Add DNS CNAME record for `hister.nl.levonk.com` in Cloudflare DNS config
- [ ] Add service catalog entry to `shared/active/02-config/ansible/infrastructure/services.yml`
- [ ] Regenerate service catalogs (`just generate-service-catalog-all`)

## Relevant Files

- `shared/active/02-config/ansible/infrastructure/ports.yml` — add port 4433 vars
- `shared/active/02-config/ansible/infrastructure/domains.yml` — add domain var
- `shared/active/02-config/ansible/infrastructure/storage.yml` — add volume var
- `levonk/active/02-config/ansible/infrastructure/domains.yml` — client override
- `levonk/active/02-config/ansible/inventories/group_vars/all.yml` — DNS CNAME
- `shared/active/02-config/ansible/infrastructure/services.yml` — catalog entry

## Acceptance Criteria

- Given the shared ports.yml, When rendered, Then `infra_port_search_hister_host` and `infra_port_search_hister_container` are defined as "4433"
- Given the shared domains.yml, When rendered, Then `infra_domain_search_hister` is defined
- Given the levonk domains.yml, When rendered, Then `infra_domain_search_hister` resolves to "hister.nl.levonk.com"
- Given the services.yml, When parsed, Then a Hister entry exists with `source_repo: "https://github.com/asciimoo/hister"`
- Given the service catalog generator runs, Then it reports "✓ All services have source_repo links"

## Implementation Notes

### Port variables (ports.yml)
```yaml
# Hister Search Engine
infra_port_search_hister_host: "4433"
infra_port_search_hister_container: "4433"
```

### Domain variable (shared domains.yml)
```yaml
# Hister Search Engine
infra_domain_search_hister: "hister.{{ infra_domain_base }}"
```

### Storage variable (storage.yml)
```yaml
# Hister Search Engine
infra_storage_hister_volume: "localnet-hister-data-volume"
```

### Client domain override (levonk domains.yml)
```yaml
# Hister Search Engine (client-specific)
infra_domain_search_hister: "hister.nl.levonk.com"
```

### DNS CNAME
Add `hister.nl.levonk.com` CNAME → `dtop202311.tale-grouper.ts.net` to the
Cloudflare DNS records in the inventory group_vars/all.yml (or wherever
`cloudflare_dns_records` is defined). Follow the pattern of existing nl
service CNAMEs.

### Service catalog entry (services.yml)
```yaml
# Hister Search Engine
- name: "Hister"
  container: "{{ infra_hostname_hister | default('localnet-hister') }}"
  machine: "dtop202311"
  category: "search"
  description: "Self-hosted search engine for browsing history and documents"
  source_repo: "https://github.com/asciimoo/hister"
  domains:
    - "infra_domain_search_hister"
  ports:
    - host: "infra_port_search_hister_host"
      container: "infra_port_search_hister_container"
      label: "Web"
  traefik: true
  network: "traefik-windows-network"
```

## Definition of Done

- All infra variables defined with `infra_` naming convention
- No hardcoded values in role or traefik config (all reference `infra_*` vars)
- Service catalog entry has `source_repo` link
- Catalog regeneration passes with no warnings
