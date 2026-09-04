---
story: "08-001"
title: "Documentation (AGENTS.md, SERVICES.md, role README)"
status: "[ ] Todo"
phase: 8
depends_on: ["07-001"]
branch: "feature/current/web-proxy-chain/story-08-001-documentation"
---

# Story 08-001: Documentation

## Goal

Update documentation to reflect the new web proxy chain.

## Files to modify

1. `shared/active/02-config/ansible/AGENTS.md` — add "Web Proxy Chain Architecture" section (matching the DNS Architecture section)
2. `shared/active/02-config/ansible/roles/proxy-web/README.md` — role README
3. Verify SERVICES.md was regenerated in story 02-001

## AGENTS.md section to add

Add a "Web Proxy Chain Architecture" section to `shared/active/02-config/ansible/AGENTS.md`,
matching the structure of the "DNS Architecture (Two-Layer)" section:

```markdown
## Web Proxy Chain Architecture

The shared `proxy-web` role deploys a 4-layer web proxy chain for HTTPS
interception, content filtering, caching, and egress routing.

### Chain Flow

Client → MITM Proxy (HTTPS decryption) → Privoxy (content filtering)
→ Varnish (caching) → Gost (egress multiplexer) → Direct/Tor

### Role: proxy-web
### Playbook: deploy-proxy-web-stack.yml
### Targets: windows_docker_hosts + cloud_servers

See `diagrams/proxy/complete-web-proxy-chain.mmd` for the full architecture diagram.
```

## Acceptance criteria

- [ ] AGENTS.md updated with Web Proxy Chain Architecture section
- [ ] Role README.md created
- [ ] SERVICES.md verified (from story 02-001)
- [ ] `just ansible-syntax` passes
