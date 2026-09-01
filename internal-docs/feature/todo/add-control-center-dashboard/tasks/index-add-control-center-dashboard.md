# Task Index: add-control-center-dashboard

PRD: `internal-docs/feature/todo/add-control-center-dashboard/feat-20260830-control-center-dashboard.md`

| Story ID | Title | Phase | Status | Assignee | Parallel-safe | Dependencies | Dependants | Modules | Branch |
|---|---|---:|---|---|---|---|---|---|---|
| 01-001 | Allocate infrastructure variables (ports, domains, storage, network) | 01 | [ ] Todo |  | true | — | 02-001, 02-002 | shared/infrastructure, levonk/infrastructure | feature/current/add-control-center-dashboard/story-01-001-infra-variables |
| 01-002 | Create build script for control-center image | 01 | [ ] Todo |  | true | — | 03-001 | scripts, justfile | feature/current/add-control-center-dashboard/story-01-002-build-script |
| 02-001 | Create Ansible role (defaults, tasks, handlers, meta) | 02 | [ ] Todo |  | true | 01-001 | 03-001 | shared/roles/dashboard-control-center | feature/current/add-control-center-dashboard/story-02-001-ansible-role |
| 02-002 | Create Traefik dynamic config template | 02 | [ ] Todo |  | true | 01-001 | 03-001 | shared/roles/proxy_traefik_windows/templates | feature/current/add-control-center-dashboard/story-02-002-traefik-config |
| 02-003 | Add Cloudflare DNS entries for both domains | 02 | [ ] Todo |  | true | 01-001 | 03-001 | shared/playbooks/configure-cloudflare-dns.yml | feature/current/add-control-center-dashboard/story-02-003-cloudflare-dns |
| 03-001 | Create deploy playbook + validate playbook + just recipes + service catalog | 03 | [ ] Todo |  | false | 01-001, 01-002, 02-001, 02-002, 02-003 | 04-001 | shared/playbooks, justfile, services.yml | feature/current/add-control-center-dashboard/story-03-001-playbooks-catalog |
| 04-001 | Test: ansible syntax, lint, check mode, project-lint | 04 | [ ] Todo |  | false | 03-001 | 05-001 | — | feature/current/add-control-center-dashboard/story-04-001-validation |
| 05-001 | Build image, deploy to dtop202311, verify both domains | 05 | [ ] Todo |  | false | 04-001 | — | — | feature/current/add-control-center-dashboard/story-05-001-deploy-verify |
