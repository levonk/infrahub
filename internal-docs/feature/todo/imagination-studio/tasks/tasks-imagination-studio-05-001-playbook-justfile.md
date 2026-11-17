---
story_id: "05-001"
story_title: "deploy + validate playbooks, just/devbox recipes, docs"
story_name: "playbook-justfile"
prd_name: "imagination-studio"
prd_file: "internal-docs/feature/todo/imagination-studio/feat-202611170854-imagination-studio.md"
phase: 5
parallel_id: 4
branch: "levonk/20261116-imagination-studio"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["03-001", "04-001"]
parallel_safe: false
modules: ["ansible-playbook", "justfile", "devbox", "docs"]
priority: "MUST"
risk_level: "low"
tags: ["playbook", "just", "devbox", "docs"]
due: "2026-11-17"
create-date: "2026-11-17"
update-date: "2026-11-17"
---

## Summary

Create `deploy-imagination-studio.yml` +
`validate-imagination-studio.yml` playbooks, just recipes, devbox.json
script entries, and doc updates (Ansible AGENTS.md mapping table,
SERVICES.md regeneration if catalog-driven). Mirrors
`deploy-comfyui.yml`/`validate-*` precedents.

## Sub-Tasks

- [ ] `shared/active/02-config/ansible/playbooks/deploy-imagination-studio.yml`
  — header comment (purpose, prerequisites: hf auth under lk, tailnet
  reachability, disk; usage incl. `--check`, `--tags`); play
  `hosts: localnet_hosts` `--limit kckinai` with full vars_files
  preamble (copy deploy-comfyui.yml's include_vars list exactly +
  required-vars assert); apply `ai-imagination-studio` role with
  `ai_studio_enabled: true`; tags: `validate`, `deps`, `dirs`,
  `checkout`, `env`, `service`, `verify`. NO model install here (that's
  story 04-001's playbook).
- [ ] `shared/active/02-config/ansible/playbooks/validate-imagination-studio.yml`
  — read-only checks per Ansible AGENTS.md "Validation & Testing
  Layers" (delegate_to localhost + ssh/docker patterns where needed for
  localnet native host): service unit active+enabled (systemctl --user
  via become_user lk), port 7870 bound to tailscale IP only (ss/netstat
  — assert NOT 0.0.0.0), `GET /api/spark/self` via uri module with
  access key? (key needed — read from STUDIO_HOME access-key file via
  slurp on host, no_log) OR unauthenticated reachability check with
  expected 401/403 (proves binding+app alive without needing key —
  prefer this), memguard unit present, managed-comfy port 8190 not
  published, disk free vs threshold, installer dir exists. Collect
  `validation_results` + `security_warnings`, display summary, don't
  fail-fast. Tags `validate`, `imagination-studio`.
- [ ] just recipes in the appropriate Justfile(s) (check where
  `ansible-deploy-comfyui`/`ansible-validate-*` live — root justfile or
  levonk/justfile): `ansible-deploy-imagination-studio`,
  `ansible-deploy-imagination-studio-models`,
  `ansible-validate-imagination-studio` (+ `-internal` variants per repo
  convention). Copy the acrm/postiz/comfyui recipe shape exactly.
- [ ] `devbox.json` — matching script entries (mirror existing
  ansible-* scripts).
- [ ] `shared/active/02-config/ansible/AGENTS.md` — add rows to
  "Playbook-to-Inventory Mapping" table for the two new playbooks
  (`localnet.yml --limit kckinai`, `localnet_hosts`, Linux, kckinai).
- [ ] SERVICES.md — regenerate via catalog generator (same as
  02-001) so imagination-studio appears; verify entry correct.
- [ ] Final sweep: `just ansible-lint`, `just ansible-syntax`,
  `--syntax-check` both new playbooks, `git status` clean review.

## Acceptance Criteria

- `just ansible-deploy-imagination-studio --check`-equivalent devbox
  command runs clean (syntax + check-mode).
- Validate playbook is read-only (no mutating modules).
- All recipes discoverable via `just --list | grep imagination`.
- AGENTS.md mapping table + SERVICES.md updated.
