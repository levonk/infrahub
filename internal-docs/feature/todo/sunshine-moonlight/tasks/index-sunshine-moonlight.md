# Task Index: sunshine-moonlight

**PRD**: `internal-docs/feature/todo/sunshine-moonlight/prd.md`
**Research**: `internal-docs/research/service/sunshine/`, `internal-docs/research/service/moonlight-qt/`
**Implementation guide**: `.agents/workflows/infrahub-add-new-service.md`

## Stories

| ID | Title | Status | Depends | Branch |
|----|-------|--------|---------|--------|
| 01-001 | Sunshine on Windows — shared ports, `media-sunshine` role, deploy+validate playbooks, services.yml entries, devbox.json scripts | [ ] Todo | — | story worktree |
| 01-002 | Moonlight on macOS fleet — homebrew cask, levonk darwin module, `media-moonlight-client` role, deploy playbook, levonk justfile recipe | [ ] Todo | — | story worktree |
| 01-003 | Vault secrets handoff (vault_sunshine_web_username/password) | [ ] Todo | — | user handoff |

## Execution Order

**Batch 1 (parallel)**: 01-001, 01-002, 01-003 — disjoint file sets:

- 01-001 touches only `shared/` Ansible (ports.yml, roles/media-sunshine,
  playbooks deploy+validate-sunshine, services.yml entries for BOTH
  services — single editor avoids merge conflicts) + `devbox.json`.
- 01-002 touches shared nix (`homebrew.nix`), `roles/media-moonlight-client`,
  `playbooks/deploy-moonlight.yml`, and levonk submodule
  (`levonk/active/02-config/nix/darwin/`, `levonk/justfile`). Story worktree
  must `git submodule update --init levonk` first.
- 01-003 is a user handoff (orchestrator-run, not a subagent).

## Deployment Notes

- Sunshine: native winget `LizardByte.Sunshine` on dtop202311 (NOT docker —
  container can't capture Windows desktop). User decision 2026-10-17.
- Moonlight pairing is automatable via `moonlight pair --pin` +
  Sunshine `POST /api/pin` (web UI basic auth) once vault creds exist.
- Web UI is TCP 47990 (NOT 47984 — that's the HTTPS GameStream port).
- `origin_web_ui_allowed = wan` needed — Tailscale 100.64.0.0/10 isn't
  RFC1918 so default `lan` refuses web UI over Tailscale.
- mDNS (UDP 5353) doesn't cross Tailscale → Moonlight "Add Host Manually"
  with `dtop202311.tale-grouper.ts.net`.
- macOS Local Network permission = one-time human click (first launch).
- Devbox env is BROKEN project-wide (packer-1.15.3 nixpkgs build crash);
  use `nix shell nixpkgs#ansible -c <cmd>` for ansible/lint until fixed.
