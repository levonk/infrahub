---
story_id: "03-001"
story_title: "ai-imagination-studio Ansible role (native install on kckinai)"
story_name: "studio-role"
prd_name: "imagination-studio"
prd_file: "internal-docs/feature/todo/imagination-studio/feat-202611170854-imagination-studio.md"
phase: 3
parallel_id: 2
branch: "levonk/20261116-imagination-studio"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["02-001"]
parallel_safe: false
modules: ["ansible-role", "systemd-user", "native-install"]
priority: "MUST"
risk_level: "medium"
tags: ["role", "native-install", "systemd", "kckinai"]
due: "2026-11-17"
create-date: "2026-11-17"
update-date: "2026-11-17"
---

## Summary

Create `shared/active/02-config/ansible/roles/ai-imagination-studio/` — a
native-install role for Imagination Studio on kckinai following the
`ai-comfyui` precedent (native, not container; `localnet_hosts`/`kckinai`
dispatch). Delivers code + deps + env + systemd user unit + service
management. Model downloads are story 04-001's separate playbook — this
role does NOT run the installer.

## Sub-Tasks

- [ ] Role skeleton: `defaults/main.yml`, `meta/main.yml`,
  `tasks/main.yml`, `handlers/main.yml`, `templates/` (env file +
  systemd unit), `files/` if needed, `README.md`. Mirror
  `roles/ai-comfyui/` structure and `roles/ai-litellm/`/`ai-treg/` for
  `ai-` prefix conventions. `meta/main.yml`: role_name
  `ai_imagination_studio`, platforms `["all"]` (arm64 DGX OS — check
  ai-comfyui's platform list and copy).
- [ ] `defaults/main.yml` — vars referencing infra vars:
  `ai_studio_enabled`, `ai_studio_ref` (pin — check upstream tags;
  VERSION file says 4.2.1; prefer a tag/SHA var, default a commit SHA or
  tag string documented in research), `ai_studio_run_user: "{{
  localnet_kckinai_ansible_user }}"` (=lk), `ai_studio_home:
  "{{ infra_storage_studio_home_dir }}"`, `ai_studio_prefix:
  "{{ infra_storage_studio_prefix_dir }}"`, `ai_studio_port:
  "{{ infra_port_ai_studio_container }}"`, `ai_studio_host:
  "{{ ansible_host }}"` (or tailscale IP resolution — see below),
  `ai_studio_install_dir`, `ai_studio_repo_url` (upstream),
  `ai_studio_verify_health` flag pattern from comfyui defaults.
- [ ] `tasks/main.yml` tagged phases:
  - `validate` — assert required vars (infra vars defined, run_user,
    repo_url, ref).
  - `deps` — ensure packages as `lk`/become where needed: git, ffmpeg,
    python3 + python3-venv (check ai-comfyui's apt block — DGX OS is
    Ubuntu/Debian-family; copy its package list + RedHat fallback),
    rsync, openssh-client, curl. Docker already present (DGX OS) — verify
    not install.
  - `dirs` — create PREFIX + STUDIO_HOME dirs owned by `lk`
    (`ansible.builtin.file`, mode `{{ infra_mode_dir }}`).
  - `checkout` — clone repo to install dir at `ai_studio_ref` (git
    module or command with creates-check; shallow clone OK? — installer
    needs full tree? shallow fine for release tarball/tag; use
    `git clone --depth 1 --branch <ref>` when ref is a tag/branch, else
    fetch SHA).
  - `env` — template env file (systemd `EnvironmentFile=` or script env):
    `HOST={{ tailscale ip }}`, `PORT=7870`, `STUDIO_HOME=...`,
    `PREFIX=...`. Tailscale IP: resolve via `tailscale ip -4` command
    (delegate to host) or `vpn_tailscale_hostname`-derived var — pick
    the mechanism ai-comfyui/bootstrap roles use for host IPs; document
    choice. Fallback: bind `HOST={{ ansible_host }}` is WRONG (LAN) —
    must be tailscale IP specifically.
  - `service` — template `~lk/.config/systemd/user/imagination-studio.service`
    (or `/etc/systemd/user/`? — check how memguard.py installs its user
    unit upstream; copy that layout): `ExecStart` per upstream
    (`bash scripts/app.sh` from install dir with env), `Restart=on-failure`,
    `WantedBy=default.target`. Then `systemctl --user daemon-reload`,
    `enable --now` as `lk` (become_user + XDG_RUNTIME_DIR env — check
    precedents; `ansible.builtin.systemd` with `scope: user` may not
    work over SSH — likely needs command/shell with proper env; document
    what works). `loginctl enable-linger lk` via become.
  - `verify` (tag `verify`) — curl `http://<ts ip>:7870/api/spark/self`
    with timeout; report status; only when `ai_studio_verify_health`.
- [ ] `handlers/main.yml` — restart service on env/unit change.
- [ ] Role README.md — purpose, vars table, usage, upstream links, notes
    (memguard, HF auth location, upgrade path).
- [ ] Do NOT include: model downloads, app start verification beyond
  health probe, Traefik, vault vars.

## Acceptance Criteria

- `devbox run -- rtk ansible-playbook --syntax-check` on any playbook
  including the role passes; `just ansible-lint` clean for new files
  (role-name rule: dir `ai-imagination-studio`, role_name
  `ai_imagination_studio`, platform `["all"]`).
- Role is idempotent (second converge = no changes).
- `--check` run against kckinai shows only intended diffs.
- Env/unit templates render correct HOST=tailnet-IP binding.
