---
story: 01-007
name: catalog-cleanup
status: "Todo"
depends: ["01-001", "01-004"]
branch: feature/current/verdaccio-dual-deployment/story-01-007-catalog-cleanup
---

# Story 01-007: Service Catalog + Cleanup Old Scaffolding

## Goal

Add verdaccio entries to the service catalog and clean up the old custom Dockerfile scaffolding.

## Tasks

1. **Service catalog** — `shared/active/02-config/ansible/infrastructure/services.yml`
   Add two entries (following the exit node dual-deployment pattern):

   ```yaml
   - name: "Verdaccio NPM Registry (cno)"
     container: "{{ infra_hostname_verdaccio_cno | default('localnet-artifact-verdaccio') }}"
     machine: "oci-cloud-server"
     category: "infra"
     description: "Private npm registry + proxy cache on OCI (cno)"
     source_repo: "https://github.com/verdaccio/verdaccio"
     domains:
       - "infra_domain_artifact_verdaccio_cno"
     ports:
       - host: "infra_port_artifact_verdaccio_host"
         container: "infra_port_artifact_verdaccio_container"
         label: "Web/API"
     traefik: true
     network: "traefik-network"

   - name: "Verdaccio NPM Registry (nl)"
     container: "{{ infra_hostname_verdaccio_nl | default('localnet-artifact-verdaccio-nl') }}"
     machine: "dtop202311"
     category: "infra"
     description: "Private npm registry + proxy cache on Windows Docker Desktop (nl)"
     source_repo: "https://github.com/verdaccio/verdaccio"
     domains:
       - "infra_domain_artifact_verdaccio_nl"
     ports:
       - host: "infra_port_artifact_verdaccio_host"
         container: "infra_port_artifact_verdaccio_container"
         label: "Web/API"
     traefik: true
     notes: "Traefik routes cross-machine via Tailscale FQDN (dtop202311.tale-grouper.ts.net)"
   ```

2. **Regenerate catalogs**:
   ```bash
   devbox run -- just generate-service-catalog-all
   ```
   Verify: "All services have source_repo links" message appears.

3. **Clean up old scaffolding** — `shared/active/03-container/services/artifact/verdaccio/`
   - The old custom Dockerfile + entrypoint approach is replaced by upstream image + Ansible templates
   - Remove: `docker/Dockerfile.verdaccio`, `assets/entrypoint-verdaccio.sh`
   - Keep: `mounts/templates/verdaccio/conf/config.yaml.template` as reference (or remove if fully superseded by Ansible template)
   - Update `README.md` to note the service is now Ansible-managed via `roles/artifact-verdaccio/`
   - Remove the verdaccio entry from `shared/active/03-container/services/artifact/docker-compose.artifact.yml`

## Acceptance Criteria

- [ ] services.yml has both cno and nl verdaccio entries with source_repo
- [ ] Both catalogs regenerated (levonk/SERVICES.md + SERVICES.md)
- [ ] Generator reports all services have source_repo links
- [ ] Old custom Dockerfile + entrypoint removed
- [ ] docker-compose.artifact.yml verdaccio entry removed
- [ ] Old scaffolding README updated to point to Ansible role

## Implementation Guide

See `.agents/workflows/infrahub-add-new-service.md` Phase 2f (Service Catalog) and Phase 2g (Regenerate).
