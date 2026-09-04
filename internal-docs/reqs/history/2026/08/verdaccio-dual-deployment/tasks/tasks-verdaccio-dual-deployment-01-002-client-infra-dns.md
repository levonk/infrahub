---
story: 01-002
name: client-infra-dns
status: "Todo"
depends: ["01-001"]
branch: feature/current/verdaccio-dual-deployment/story-01-002-client-infra-dns
---

# Story 01-002: Client Infrastructure Values + DNS

## Goal

Add client-specific overrides and Cloudflare DNS CNAME records for both verdaccio domains.

## Tasks

1. **Client domains** — `levonk/active/02-config/ansible/infrastructure/domains.yml`
   - Add `infra_domain_artifact_verdaccio_cno: "npmjs.cno.levonk.com"`
   - Add `infra_domain_artifact_verdaccio_nl: "npmjs.nl.levonk.com"`

2. **Cloudflare DNS** — Add CNAME records to the cloudflare_dns_records variable
   - File: `levonk/active/02-config/ansible/inventories/group_vars/all.yml` (or wherever cloudflare_dns_records is defined)
   - `npmjs.cno.levonk.com` → CNAME → `oci.tale-grouper.ts.net`
   - `npmjs.nl.levonk.com` → CNAME → `dtop202311.tale-grouper.ts.net`
   - Follow the pattern used by existing exit node CNAMEs (vpn.cno.levonk.com, etc.)

3. **Check existing DNS playbook** — `shared/active/02-config/ansible/playbooks/configure-cloudflare-dns.yml`
   - Add entries for the two new domains following the exit node pattern (lines ~225-249)

## Acceptance Criteria

- [ ] levonk domains.yml has both cno and nl verdaccio domains
- [ ] Cloudflare DNS playbook has entries for both domains
- [ ] CNAMEs point to correct Tailscale FQDNs (cno → oci, nl → dtop202311)
- [ ] No hardcoded IPs — CNAMEs to Tailscale FQDNs only

## Implementation Guide

See `.agents/workflows/infrahub-add-new-service.md` Phase 2 (Client Infrastructure Values).
