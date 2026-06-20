---
story_id: "03-002"
story_title: "Configure Cloudflare DNS records"
story_name: "cloudflare-dns-config"
prd_name: "traefik-authelia-cloudflare"
prd_file: "shared/active/08-docs/reqs/2026/20260620-traefik-authelia-cloudflare.md"
phase: 3
parallel_id: 2
branch: "feature/current/traefik-authelia-cloudflare/story-03-002-cloudflare-dns-config"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["01-004", "03-001"]
parallel_safe: true
modules: ["cloudflare-dns", "cloudflare-api"]
priority: "MUST"
risk_level: "high"
tags: ["feat", "dns", "cloudflare", "security"]
due: "2026-07-02"
created_at: "2026-06-20"
updated_at: "2026-06-20"
---

## Summary

Configure Cloudflare DNS records using the cloudflare-dns Ansible role to point domains to the OCI cloud server IP. This task will create A records for `search.levonk.com` and `traefik.levonk.com` (or other proxy domains), enabling external access to services through the Traefik proxy stack with SSL termination.

## Sub-Tasks

- [ ] Deploy cloudflare-dns role to OCI cloud server
- [ ] Configure Cloudflare API token in vault
- [ ] Create A record for `search.levonk.com` pointing to OCI IP
- [ ] Create A record for `traefik.levonk.com` (if needed) pointing to OCI IP
- [ ] Configure DNS TTL settings for optimal performance
- [ ] Test DNS resolution for configured domains
- [ ] Verify DNS propagation completes
- [ ] Test SSL certificate generation with new DNS records
- [ ] Configure Cloudflare proxy mode (DNS-only, not full proxy)
- [ ] Set up DNS record monitoring and change tracking
- [ ] Document DNS record management procedures
- [ ] Test DNS record update and deletion procedures
- [ ] Verify Cloudflare API rate limit compliance
- [ ] Create DNS record backup and restore procedures

## Relevant Files

- `shared/active/02-config/ansible/roles/cloudflare-dns/` - Role deployment
- `shared/active/02-config/ansible/host_vars/oci-cloud-server.yml` - Configuration variables
- `shared/active/02-config/ansible/host_vars/oci-cloud-server.vault` - Cloudflare API token
- `shared/active/02-config/ansible/playbooks/configure-cloudflare-dns.yml` - DNS configuration playbook
- `shared/active/02-config/ansible/vars/cloudflare-domains.yml` - Domain configuration

## Acceptance Criteria

- [ ] A record for `search.levonk.com` is created and pointing to OCI IP
- [ ] A record for `traefik.levonk.com` is created (if needed)
- [ ] DNS resolution works for configured domains
- [ ] DNS propagation completes successfully
- [ ] SSL certificate generation works with new DNS records
- [ ] Cloudflare proxy mode is set to DNS-only
- [ ] API token is properly secured in vault
- [ ] DNS TTL settings are optimized for performance
- [ ] DNS record changes are tracked and monitored
- [ ] Documentation is complete for DNS management procedures
- [ ] Backup and restore procedures are tested
- [ ] No hardcoded values in DNS configuration

## Test Plan

- Unit: Test cloudflare-dns role with staging environment
- DNS: Verify DNS resolution with `dig` and `nslookup`
- Propagation: Monitor DNS propagation with online tools
- SSL: Test Let's Encrypt certificate generation with new DNS
- API: Verify Cloudflare API rate limit compliance
- Backup: Test DNS record backup and restore procedures
- Update: Test DNS record update functionality

## Observability

- Monitor DNS record changes via Cloudflare API
- Track DNS propagation timing and success rates
- Log all DNS API operations for audit purposes
- Document DNS resolution performance metrics
- Set up alerts for DNS record changes

## Compliance

- Ensure Cloudflare API tokens are stored in Ansible vault
- Follow AGENTS.md guidelines for variable-driven configuration
- Reference AGENTS.md files in DNS configuration documentation
- Implement proper DNS security best practices
- Follow Cloudflare API usage policies and rate limits

## Risks & Mitigations

- Risk: DNS propagation delays — Mitigation: Monitor propagation and document timing
- Risk: API rate limiting — Mitigation: Implement proper backoff and idempotency
- Risk: SSL certificate failures — Mitigation: Test ACME with staging environment first
- Risk: DNS misconfiguration — Mitigation: Comprehensive testing and validation
- Risk: API token exposure — Mitigation: Vault storage and access controls

## Dependencies & Sequencing

- Depends on: Story 01-004 (cloudflare-dns role), Story 03-001 (SearXNG integration)
- Unblocks: Story 03-003 (Monitoring and logging)
- Must complete before: External service access testing

## Definition of Done

- DNS records are created and pointing to OCI IP
- DNS resolution works for all configured domains
- SSL certificates are generated successfully
- Cloudflare proxy mode is configured correctly
- API token is properly secured in vault
- Documentation is complete and accurate
- Backup and restore procedures are tested
- No hardcoded values in DNS configuration

## Commit Conventions

- Use conventional commits: `feat(dns): configure Cloudflare DNS records for proxy stack domains`
- Scope commits to specific domains and operations
- Reference story ID in commit messages: `Story 03-002`