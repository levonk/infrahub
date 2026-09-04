---
story_id: "03-001"
story_title: "Playbook integration"
story_name: "playbook"
prd_name: "hister-search-deploy"
prd_file: "internal-docs/feature/todo/hister-search-deploy/feat-202608222054-hister-search-deploy.md"
phase: 3
parallel_id: 1
branch: "feature/current/hister-search-deploy/story-03-001-playbook"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["02-001", "02-002"]
parallel_safe: false
modules: ["playbook", "deployment"]
priority: "MUST"
risk_level: "low"
tags: ["ansible", "playbook"]
due: "2026-08-22"
create-date: "2026-08-22"
update-date: "2026-08-22"
---

## Summary

Add the `search-hister` role to the Windows Docker deployment playbook so it
can be deployed alongside the other nl services (Traefik, Homepage, TraLa,
Verdaccio, etc.).

## Sub-Tasks

- [ ] Identify the correct playbook for Windows Docker service deployment
- [ ] Add `search-hister` role to the playbook with appropriate tags
- [ ] Verify the playbook syntax passes

## Relevant Files

- `shared/active/02-config/ansible/playbooks/deploy-proxy-web-stack.yml` (or equivalent Windows Docker playbook)

## Acceptance Criteria

- Given the deployment playbook, When run with `--syntax-check`, Then it passes
- Given the playbook targets windows_docker_hosts, When the search-hister role is included, Then it deploys before or alongside the proxy_traefik_windows role (so the container exists before Traefik tries to route to it)

## Implementation Notes

Find the existing playbook that deploys the proxy_traefik_windows role and
other nl services. Add the search-hister role to it:

```yaml
- role: search-hister
  tags: ["deploy", "hister"]
```

The search-hister role should run BEFORE proxy_traefik_windows so the container
exists when Traefik tries to connect it to the network and route to it.

## Definition of Done

- Playbook includes search-hister role with correct tags
- Syntax check passes
- Role ordering is correct (hister before traefik)
