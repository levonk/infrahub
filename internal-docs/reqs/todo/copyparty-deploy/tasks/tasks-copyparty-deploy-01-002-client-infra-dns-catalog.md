---
story_id: "01-002"
story_title: "Client infrastructure overrides + DNS + service catalog"
story_name: "client-infra-dns-catalog"
prd_name: "copyparty-deploy"
prd_file: "internal-docs/feature/todo/copyparty-deploy/feat-202608312209-copyparty-deploy.md"
phase: 1
parallel_id: 2
branch: "feature/current/copyparty-deploy/story-01-002-client-infra-dns-catalog"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["01-001"]
parallel_safe: true
modules: ["client-infra", "dns", "catalog"]
priority: "MUST"
risk_level: "low"
tags: ["feat", "infrastructure", "client", "dns", "catalog"]
due: "2026-08-31"
create-date: "2026-08-31"
update-date: "2026-08-31"
---

## Summary

Add client-specific domain override for `files.levonk.com` in the levonk
submodule, add the Cloudflare DNS CNAME record, add the service catalog entry
to `services.yml`, and regenerate both service catalogs.

## Sub-Tasks

- [ ] Add domain override to `levonk/active/02-config/ansible/infrastructure/domains.yml`:
  - `infra_domain_storage_copyparty: "files.levonk.com"`
  - Add a comment header `# copyparty (File Sharing Server) — client-specific`
- [ ] Add service catalog entry to `shared/active/02-config/ansible/infrastructure/services.yml`:
  ```yaml
  # copyparty (File Sharing Server)
  - name: "copyparty"
    container: "{{ infra_hostname_copyparty | default('copyparty') }}"
    machine: "oci-cloud-server"
    category: "ui"
    description: "Self-hosted file sharing server with WebDAV, chunked uploads, and media indexing"
    source_repo: "https://github.com/9001/copyparty"
    domains:
      - "infra_domain_storage_copyparty"
    ports:
      - host: "infra_port_storage_copyparty_host"
        container: "infra_port_storage_copyparty_container"
        label: "Web"
    traefik: true
    health_endpoint: "/"
    pipeline: "none"
    alert_labels:
      pipeline: "none"
      stage: "storage"
      service: "copyparty"
  ```
- [ ] Regenerate client catalog: `devbox run -- just generate-service-catalog`
- [ ] Regenerate shared catalog: `devbox run -- just generate-service-catalog-shared`
- [ ] Verify both catalogs report `✓ All services have source_repo links`
- [ ] Verify `levonk/SERVICES.md` and `SERVICES.md` both contain the copyparty entry

**NOTE on DNS**: The Cloudflare DNS CNAME for `files.levonk.com` is deployed
in Phase 5 (Deploy) via the `deploy-copyparty.yml` playbook, not in this story.
This story only adds the catalog entry and client domain override.

## Relevant Files

- `levonk/active/02-config/ansible/infrastructure/domains.yml` — add client domain override
- `shared/active/02-config/ansible/infrastructure/services.yml` — add catalog entry
- `levonk/SERVICES.md` — regenerated (do not edit manually)
- `SERVICES.md` — regenerated (do not edit manually)

## Acceptance Criteria (Gherkin)

- Given the client `domains.yml`, When referencing `infra_domain_storage_copyparty`, Then it resolves to `"files.levonk.com"`
- Given `services.yml`, When the catalog generator runs, Then the output includes copyparty with `source_repo: "https://github.com/9001/copyparty"`
- Given both regenerated catalogs, When searching for "copyparty", Then both `levonk/SERVICES.md` and `SERVICES.md` contain the entry

## Test Plan

- Manual: `devbox run -- just generate-service-catalog` succeeds and reports `✓ All services have source_repo links`
- Manual: `devbox run -- just generate-service-catalog-shared` succeeds
- Manual: `grep -c "copyparty" levonk/SERVICES.md SERVICES.md` returns >= 1 for both

## Definition of Done

- Client domain override added
- Service catalog entry added with `source_repo` field
- Both catalogs regenerated successfully
- No `source_repo` warnings from the generator
