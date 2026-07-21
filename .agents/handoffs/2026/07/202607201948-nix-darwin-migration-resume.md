# nix-darwin-migration: resume after workflow + execute-upsert fixes

**Date**: 2026-07-20
**Session**: Ran infrahub-add-new-service-orchestrator against the nix-darwin-migration PRD; discovered resume-mistakes in the orchestrator workflow and execute-upsert skill; fixed both; handed off for a fresh orchestrator session.
**Status**: In progress — Phase 4 (Test) and Phase 5 (Deploy) remain

## Current State

### Completed this session

- **Phase 1 (Initialize)**: Read AGENTS.md, verified devbox/rtk/just environment (nix 2.32.2, devbox 0.17.3, rtk 0.43.0, just 1.51.0). SSH to target verified.
- **Phase 1 (Resume Detection)**: Discovered the nix-darwin-migration stories 01-001, 01-002, 01-003, 02-001, 03-001 are all `[x] Done` on the `feature/current/nix-darwin-migration/story-03-001-playbook-rewrite` branch (checked out in worktree at `/Users/micro/p/gh/levonk/infrahub-worktrees/story-03-001`). Only 04-001 (runbook + ADR) is `[ ] Todo`. The current branch in the main repo (`feature/current/nix-cache-chain/planning`) had stale task status — the real status is on the story-03-001 branch.
- **Phase 4 (Test, partial)**: ansible syntax-check passed for all three playbooks: `bootstrap-macos-host.yml`, `configure-macos-host.yml`, `macos-os-update.yml`. Did not run `--check` dry-run yet (blocked on sudo — see below).
- **Root-cause fix committed**: The macOS bootstrap playbook was missing a NOPASSWD sudoers task for `auser` (the Linux `host-os-bootstrap` role has one, the macOS one did not). Added `Grant auser passwordless sudo (NOPASSWD)` task to `bootstrap-macos-host.yml` (writes `/etc/sudoers.d/auser` mode 0440, validates with `visudo -cf %s`). Committed as `4aa3511` on `feature/current/nix-darwin-migration/story-03-001-playbook-rewrite` and pushed. **User is running the bootstrap playbook on 192.168.12.210 to apply this one-time sudoers fix.**
- **Workflow fix committed**: Added Resume Detection section to `infrahub-add-new-service-orchestrator.md` (Phase 1) — checks for existing PRD/task index, reads Status column, detects worktrees/branches, skips Phase 2 if research dir exists. Committed as `ef13aa4` on `feature/current/workflow-fixes/resume-detection` in the infrahub repo (NOT pushed yet).
- **execute-upsert skill fix committed**: Updated `execute-upsert` to v1.2.0 with run-as-much-as-possible behavior — blocked stories marked `[!] Blocked` with reason in index + `## Blocker` section (question/options/recommendation/why), proceeds to next runnable story, presents consolidated Phase 5 Blocker Report. Committed as `a7c6e9d` on `feature/current/execute-upsert/blocked-proceed-mode` in the skills-src repo. Build + validate passed.

### Blocking Issues

1. **Sudo on lzkmbp2018 (192.168.12.210)**: The bootstrap playbook's new sudoers task needs sudo to run (chicken-and-egg — the task that grants passwordless sudo itself requires sudo). User chose to run the bootstrap playbook manually on the target to apply the one-time fix. **Waiting for user confirmation that bootstrap ran and `/etc/sudoers.d/auser` exists on 192.168.12.210.** Once confirmed, future ansible runs (configure, os-update) will be passwordless.
2. **execute-upsert skill not yet re-installed**: The updated execute-upsert skill (v1.2.0) is committed in skills-src but not yet built/published/installed into `~/.config/devin/skills/execute-upsert/`. The orchestrator's Phase 3 delegates to the installed skill. To use the new blocked-proceed behavior, the skill needs to be rebuilt and installed (or the orchestrator can inline the behavior from the source).

## Project Overview

### Objective

Complete the nix-darwin migration for the macOS fleet: replace imperative Ansible macOS system config with a declarative nix-darwin flake in infrahub, shrink the bootstrap playbook, add a configure playbook that runs `darwin-rebuild switch`, and validate against `192.168.12.210` (lzkmbp2018, x86_64 Darwin 15.7.7).

### Current Status

- PRD: `internal-docs/feature/2026/07/nix-darwin-use/feat-202607060157-nix-darwin-migration.md`
- Task index: `internal-docs/feature/2026/07/nix-darwin-use/tasks/index-nix-darwin-migration.md`
- Stories 01-001 through 03-001: `[x] Done` on branch `feature/current/nix-darwin-migration/story-03-001-playbook-rewrite` (worktree at `/Users/micro/p/gh/levonk/infrahub-worktrees/story-03-001`)
- Story 04-001 (runbook + ADR): `[ ] Todo`
- Implementation worktree: `/Users/micro/p/gh/levonk/infrahub-worktrees/story-03-001` (branch `feature/current/nix-darwin-migration/story-03-001-playbook-rewrite`)
- Workflow-fix branch: `feature/current/workflow-fixes/resume-detection` in main infrahub repo (commit `ef13aa4`, NOT pushed)

## Key Decisions Made

- **Root-cause fix over workaround**: The missing sudoers task was added to the bootstrap playbook (the canonical, idempotent place) rather than manually patching sudoers on one host. This fixes the issue for all future Mac bootstraps.
- **Resume Detection in workflow**: The orchestrator now detects existing PRD/task index/worktrees before re-running phases. Status column conventions (`[ ] Todo`, `[~] In-Progress`, `[x] Done`, `[!] Blocked`) are now documented in both the orchestrator workflow and the execute-upsert skill.
- **Blocked-proceed mode in execute-upsert**: The skill no longer stops at the first blocker. It marks blocked stories, proceeds to runnable ones, and presents a consolidated blocker report at the end with question/options/recommendation/why.

## Technical Context

### Stack/Tools

- infrahub: Ansible + Nix + devbox + just
- Target: lzkmbp2018 (192.168.12.210), x86_64 Darwin 15.7.7, auser admin, Nix 2.34.4 at `/nix/var/nix/profiles/default/bin/nix`, Tailscale CLI at `/usr/local/bin/tailscale` (app binary broken), no brew in auser PATH
- Control: lzkmbp2016 (this machine), Tailscale SSH to both lzkmbp2018.tale-grouper.ts.net and 192.168.12.210 works with key `~/.ssh/lzkmbp2016-micro-oracle`
- skills-src: Go templater + just build, `just build current` renders to `build/current/skills/`

### Important Files

- `shared/active/02-config/ansible/playbooks/bootstrap-macos-host.yml` — shrunk to 5 tasks + new sudoers task (commit `4aa3511`)
- `shared/active/02-config/ansible/playbooks/configure-macos-host.yml` — runs `darwin-rebuild switch` + pmset/chflags/windowserver
- `shared/active/02-config/ansible/playbooks/macos-os-update.yml` — `softwareupdate --install --all --restart`
- `shared/active/02-config/nix/darwin/` — nix-darwin flake + modules + per-host configs
- `justfile` lines 400-427 — `ansible-bootstrap-macos`, `ansible-configure-macos`, `ansible-macos-os-update` recipes (all use `--ask-become-pass` — after sudoers fix, can drop that flag)
- `levonk/active/02-config/ansible/inventories/macos-hosts.yml` — maps lzkmbp2016/2018 to Tailscale hostnames, `macos_nix_flake_dir` removed
- `~/.ansible/vault_password` — vault password file (per AGENTS.md)

### Environment Notes

- All ansible commands MUST use `cd ~/p/gh/levonk/infrahub-worktrees/story-03-001 && devbox run -- rtk ansible-playbook ...`
- The worktree is on the story-03-001 branch which has all completed story work + the sudoers fix
- The main infrahub repo is on `feature/current/workflow-fixes/resume-detection` (the workflow fix branch)
- skills-src is on `feature/current/execute-upsert/blocked-proceed-mode` (the skill fix branch)

## Next Steps (Priority Order)

1. **Wait for user confirmation** that the bootstrap playbook ran on 192.168.12.210 and `/etc/sudoers.d/auser` exists. Verify with: `ssh -i ~/.ssh/lzkmbp2016-micro-oracle auser@192.168.12.210 'sudo -n true && echo NOPASSWD_OK'`
2. **Phase 4 (Test) — run `--check` dry-runs** against lzkmbp2018:
   ```bash
   cd ~/p/gh/levonk/infrahub-worktrees/story-03-001
   devbox run -- rtk ansible-playbook -i levonk/active/02-config/ansible/inventories/macos-hosts.yml \
     shared/active/02-config/ansible/playbooks/configure-macos-host.yml \
     --check --diff --vault-password-file ~/.ansible/vault_password \
     -e ansible_host=192.168.12.210 -l lzkmbp2018
   ```
   (Override ansible_host to LAN IP since Tailscale hostname works but the user specified 192.168.12.210. After sudoers fix, no `--ask-become-pass` needed.)
3. **Phase 5 (Deploy) — run configure playbook live** against lzkmbp2018 (same command without `--check`). This runs `darwin-rebuild switch` on the target.
4. **Phase 6 (Verify)** — confirm on 192.168.12.210: `dscl . -read /Users/auser UniqueID` succeeds, `darwin-rebuild` applied system defaults, no restart loops, nix-darwin flake at `~/.local/share/infrahub/shared/active/02-config/nix/darwin/`.
5. **Phase 4 (Execute) — story 04-001 (runbook + ADR)**: Dispatch a subagent to write the local validation runbook + ADR recording the three-layer split decision. Story file: `internal-docs/feature/2026/07/nix-darwin-use/tasks/tasks-nix-darwin-migration-04-001-runbook-adr.md`.
6. **Phase 7 (Deliver)** — update AGENTS.md with any learnings (e.g., "macOS bootstrap must grant NOPASSWD sudo for auser"), final commit on story-03-001 branch.
7. **Push the workflow-fix branch** (`feature/current/workflow-fixes/resume-detection`) and open a PR for the orchestrator resume-detection fix.
8. **Push the execute-upsert skill fix** (`feature/current/execute-upsert/blocked-proceed-mode`) and rebuild/install the skill into `~/.config/devin/skills/execute-upsert/` so future orchestrator runs use v1.2.0. This branch now has two commits: `a7c6e9d` (blocked-proceed mode) and `f6a23e1` (disruption-handoff protocol — new shared include `disruption-handoff.md.tmpl` wired into execute-upsert so any future run that stops with work remaining auto-invokes the handoff skill).

## Success Criteria

- ✅ `ansible-playbook --syntax-check` passes for bootstrap/configure/os-update playbooks (DONE this session)
- ⬜ `ansible-playbook --check` (dry-run) passes for configure playbook against lzkmbp2018
- ⬜ `just ansible-configure-macos` succeeds against lzkmbp2018 (live deploy)
- ⬜ On 192.168.12.210: `dscl . -read /Users/auser UniqueID` succeeds, nix-darwin system defaults applied
- ⬜ Story 04-001 marked `[x] Done` in task index
- ⬜ All stories `[x] Done` or `[!] Blocked` in index — no `[ ] Todo` left
- ⬜ Workflow-fix branch pushed + PR opened
- ⬜ execute-upsert v1.2.0 built + installed

## Open Questions/Blockers

- **Blocker 1**: Did the bootstrap playbook run successfully on 192.168.12.210? Is `/etc/sudoers.d/auser` now present? (User is running it manually — waiting for confirmation.)
- **Question**: Should the orchestrator drop `--ask-become-pass` from the justfile recipes now that auser has NOPASSWD sudo? Or keep it as a fallback for hosts that haven't been re-bootstrapped yet? **Recommendation**: Keep `--ask-become-pass` in the justfile for now (backward compat with hosts that haven't received the sudoers fix), but the live deploy commands can omit it for lzkmbp2018 specifically.
- **Question**: The execute-upsert skill v1.2.0 is committed in skills-src but not installed. Should the fresh orchestrator session install it first, or inline the blocked-proceed behavior? **Recommendation**: Install it first — run `just build current` in skills-src, then copy `build/current/skills/execution/execute-upsert/` to `~/.config/devin/skills/execute-upsert/`.

## Do Not

- Do NOT re-execute stories 01-001 through 03-001 — they are `[x] Done` on the story-03-001 branch.
- Do NOT edit the vault directly — use the agent→user handoff docker command from AGENTS.md.
- Do NOT run `--ask-become-pass` against lzkmbp2018 after the sudoers fix is applied — it will hang waiting for input that isn't needed.
- Do NOT hardcode IPs/ports in playbooks — use variables per AGENTS.md.
- Do NOT convert the `levonk/` submodule to a regular directory.
- Do NOT re-create the story branches that already exist.

## Suggested Skills

- **ansible** — for the live deploy (Phase 5) and verification (Phase 6); already invoked this session
- **execute-upsert** (v1.2.0) — for story 04-001 execution; install from skills-src `feature/current/execute-upsert/blocked-proceed-mode` branch first
- **handoff** — to capture context again if the fresh session needs to stop

## Additional Context

- **Project**: infrahub nix-darwin-migration
- **PRD**: `internal-docs/feature/2026/07/nix-darwin-use/feat-202607060157-nix-darwin-migration.md`
- **Task index**: `internal-docs/feature/2026/07/nix-darwin-use/tasks/index-nix-darwin-migration.md` (read from the story-03-001 branch for accurate status)
- **ADR Compliance**: Hybrid secret storage (ADR-20260624001), Infrastructure consolidation (ADR-20260625001)
- **Git Workflow**: Story branches under `feature/current/nix-darwin-migration/story-*`; the most advanced is `story-03-001-playbook-rewrite` (in worktree). Workflow fix on separate branch `feature/current/workflow-fixes/resume-detection`. Skill fix in skills-src on `feature/current/execute-upsert/blocked-proceed-mode`.
- **Four commits this session**:
  1. `4aa3511` (infrahub, story-03-001 branch) — `fix(ansible): grant auser passwordless sudo in macOS bootstrap` — PUSHED
  2. `ef13aa4` (infrahub, workflow-fixes branch) — `fix(workflow): add resume detection to add-new-service orchestrator` — NOT pushed
  3. `a7c6e9d` (skills-src, execute-upsert branch) — `feat(execute-upsert): run-as-much-as-possible with blocker report` — NOT pushed
  4. `f6a23e1` (skills-src, execute-upsert branch) — `feat(execute-upsert): add disruption-handoff protocol for session continuity` — NOT pushed. Adds new shared include `src/current/includes/disruption-handoff.md.tmpl` wired into execute-upsert — when execution stops with work remaining, invokes the `handoff` skill so a fresh session can resume. This is the protocol I used to write this handoff document.
