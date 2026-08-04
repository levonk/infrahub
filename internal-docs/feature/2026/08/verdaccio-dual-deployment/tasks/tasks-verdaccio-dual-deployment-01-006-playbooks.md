---
story: 01-006
name: playbooks
status: "Todo"
depends: ["01-004", "01-005"]
branch: feature/current/verdaccio-dual-deployment/story-01-006-playbooks
---

# Story 01-006: Deployment + Validation Playbooks

## Goal

Create deployment and validation playbooks for verdaccio, plus Just recipes.

## Tasks

1. **Deployment playbook** — `shared/active/02-config/ansible/playbooks/deploy-verdaccio.yml`
   - hosts: cloud_servers + windows_docker_hosts
   - roles: [artifact-verdaccio]
   - Run on both inventories: oci.yml (cno) + windows-docker.yml (nl)
   - Tags: ["deploy", "verdaccio"]

2. **Validation playbook** — `shared/active/02-config/ansible/playbooks/validate-verdaccio.yml`
   - Read-only post-deployment checks
   - Check container status (community.docker on cno, docker CLI on nl)
   - Check `/-/ping` endpoint responds
   - Check Traefik routing (curl https://npmjs.cno.levonk.com/-/ping, https://npmjs.nl.levonk.com/-/ping)
   - Record results in validation_results fact, display summary
   - Tags: ["validate", "verdaccio"]

3. **Just recipes** — add to Justfile:
   - `ansible-deploy-verdaccio`: deploy to both cno + nl
   - `ansible-validate-verdaccio`: validate both instances
   - Follow existing recipe patterns (ansible-deploy-infra, ansible-validate-infra)

4. **DNS deployment** — ensure the Cloudflare DNS playbook updates both CNAMEs
   - May already be handled by story 01-002 if DNS entries were added to configure-cloudflare-dns.yml

## Acceptance Criteria

- [ ] deploy-verdaccio.yml playbook created
- [ ] validate-verdaccio.yml playbook created
- [ ] Just recipes added
- [ ] Playbooks target both cloud_servers and windows_docker_hosts
- [ ] Validation checks /-/ping on both domains via Traefik
- [ ] ansible-syntax-check passes on both playbooks

## Implementation Guide

See `.agents/workflows/infrahub-add-new-service.md` and the Ansible AGENTS.md "Validation & Testing Layers" section.
