---
story_id: "04-001"
story_title: "deploy-imagination-studio-models.yml async install playbook"
story_name: "model-install-playbook"
prd_name: "imagination-studio"
prd_file: "internal-docs/feature/todo/imagination-studio/feat-202611170854-imagination-studio.md"
phase: 4
parallel_id: 3
branch: "levonk/20261116-imagination-studio"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["02-001", "03-001"]
parallel_safe: false
modules: ["ansible-playbook", "async-install"]
priority: "MUST"
risk_level: "medium"
tags: ["playbook", "async", "model-download"]
due: "2026-11-17"
create-date: "2026-11-17"
update-date: "2026-11-17"
---

## Summary

Create `shared/active/02-config/ansible/playbooks/deploy-imagination-studio-models.yml`
— a separate playbook that runs the upstream model installer
(`oneshot-setup-spark.sh --all --h3-image`) as `lk` on kckinai via Ansible
`async`/`poll: 0` with a status file for progress polling. ~423 GB of
HF downloads cannot run synchronously.

## Sub-Tasks

- [ ] Playbook header comment: purpose (model/component install ONLY —
  code+service come from deploy-imagination-studio.yml), prerequisites
  (role converged, hf auth present), usage incl. `--check` and
  `--tags status`.
- [ ] Play `hosts: localnet_hosts` `--limit kckinai`, `become: false`
  (runs as ansible/`lk` user — check connection vars; upstream requires
  user-level install, no root) with vars_files preamble copied from
  `deploy-comfyui.yml`/bootstrap playbook (shared + client infra vars,
  required-vars assert).
- [ ] Preflight tasks: assert install dir exists (role ran), assert
  `~lk/.cache/huggingface/token` exists (stat, no_log-safe — existence
  check only, never read contents), df check vs required size var
  (`ai_studio_models_min_free_gb`, default ~450), installer flags var
  `ai_studio_install_flags: "--all --h3-image"`.
- [ ] Install task: `ansible.builtin.command`/`shell` running
  `bash oneshot-setup-spark.sh {{ ai_studio_install_flags }}` in install
  dir, `async: 7200`+`poll: 0`, writes async_status to a file under
  STUDIO_HOME (e.g. `{{ infra_storage_studio_home_dir }}/.ansible-async/`).
  IMPORTANT: installer prints a license checklist then proceeds —
  check oneshot-setup-cuda.sh for interactivity (GATE_MODE vars may
  allow non-interactive; research notes checklist_gate functions —
  verify `--yes`/env bypass exists, else document `nohup`+log-file
  approach instead of async module).
- [ ] `status` tag path: tasks that tail the installer log/progress
  (the installer writes status somewhere? check upstream for a progress
  file — `spark/progress_file.py` exists!) and report model dirs
  presence via stat/find. Idempotent re-runs safe (installer skips
  existing files via `missing()`).
- [ ] `verify` tag path: run `bash oneshot-setup-spark.sh --verify`
  (upstream supports it) synchronously or async-short, report summary.
- [ ] Post-install: ensure memguard unit state reported
  (`scripts/memguard.py status`), print next-steps (service start,
  access key retrieval command).
- [ ] Document in header: expected duration, bandwidth sensitivity,
  resume behavior (re-run skips fetched files), failure modes (gated
  repo → check hf auth).

## Acceptance Criteria

- `--syntax-check` passes; `just ansible-lint` clean.
- `--check` shows only stat/assert diffs (no mutations).
- Async task does not block playbook; status tag reports progress.
- No secrets in tasks/logs (token file never read — stat only).
