---
story_id: "04-002"
story_title: "Deploy nix.conf client config and verify substitution"
story_name: "deploy-client-config"
prd_name: "nix-cache-chain"
prd_file: "internal-docs/feature/2026/07/nix-cache-chain/feat-202607081745-nix-cache-chain.md"
phase: 4
parallel_id: 2
branch: "feature/current/nix-cache-chain/story-04-002-deploy-client-config"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["03-001", "04-001"]
parallel_safe: false
modules: ["operational"]
priority: "MUST"
risk_level: "medium"
tags: ["feat", "operational", "deploy", "nix", "config"]
due: "2026-08-05"
created_at: "2026-07-08"
updated_at: "2026-07-08"
---

## Summary

Execute the `nix-client-config` role via the `nix-cache.yml` playbook to deploy nix.conf substituter configuration on all 5 Nix-running machines. Verify that Nix actually uses the new cache chain by running a test build and checking substitution logs.

## Current State

- **Relevant files and their roles:**
  - `shared/active/02-config/ansible/playbooks/nix-cache.yml` — playbook with `client-config` tag
  - `shared/active/02-config/ansible/roles/nix-client-config/` — role from Story 02-005
  - All cache services must be running (Story 04-001 complete)

- **nix.conf substituter chain (from PRD FR-5):**
  ```
  substituters = [
    "http://127.0.0.1:5000?priority=10"  (local Harmonia)
    "http://<regional-ncps-ip>:8080?priority=20"  (regional ncps)
  ]
  ```

- **Build/test/lint commands:**
  | Purpose | Command | Expected Result |
  |---------|---------|-----------------|
  | Deploy client config | `devbox run -- rtk ansible-playbook -i <all-inventories> shared/active/02-config/ansible/playbooks/nix-cache.yml --tags client-config --vault-password-file ~/.ansible/vault_password` | exit 0 |
  | Verify substituters | `nix show-config | grep substituters` on each machine | shows Harmonia + ncps |
  | Test substitution | `nix-build --expr '...' --substituters 'http://127.0.0.1:5000'` | pulls from cache |

## Scope

**In scope:**
- Deploy nix.conf on all 5 Nix machines
- Verify substituters are configured correctly
- Run a test build to verify substitution works end-to-end
- Verify Nix daemon restarted with new config

**Out of scope:**
- Cache service deployment (Story 04-001)
- Code changes to roles or playbook

## Sub-Tasks

- [ ] Task 1 — Deploy nix.conf on all 5 machines
  `devbox run -- rtk ansible-playbook -i <all-inventories> shared/active/02-config/ansible/playbooks/nix-cache.yml --tags client-config --vault-password-file ~/.ansible/vault_password`
  **Verify**: Playbook exits 0, all tasks OK

- [ ] Task 2 — Verify nix.conf on each machine
  On each machine, check `/etc/nix/nix.conf` contains the correct substituters with priorities.
  **Verify**: `nix show-config | grep -A5 substituters` → shows `http://127.0.0.1:5000?priority=10` and `http://<regional-ncps>:8080?priority=20`

- [ ] Task 3 — Verify trusted-public-keys
  **Verify**: `nix show-config | grep trusted-public-keys` → shows Harmonia public key + cache.nixos.org key

- [ ] Task 4 — Test substitution on a LAN machine (lzkmbp2016 or lzkmbp2018)
  Run a test build that pulls from the cache: `nix-build --expr 'import <nixpkgs> {}' -A hello` with verbose substitution logging.
  **Verify**: `nix build nixpkgs#hello --verbose 2>&1 | grep -E 'harmonia|ncps|ncro'` → shows cache hits from the new chain

- [ ] Task 5 — Test substitution on a cloud machine (oci-cloud-server or isolation-vm)
  Same test as Task 4 but on a cloud machine to verify the cloud regional ncps is used.
  **Verify**: Substitution logs show hits from cloud ncps → ncro chain

- [ ] Task 6 — Verify cache miss handling
  Build a package not in any cache and verify it falls through to cache.nixos.org via ncro.
  **Verify**: `nix build nixpkgs#<uncommon-package> --verbose 2>&1 | grep -E 'cache.nixos.org|ncro'` → shows fallback to cloud source

## Relevant Files

- `shared/active/02-config/ansible/playbooks/nix-cache.yml` — playbook (READ ONLY)
- `shared/active/02-config/ansible/roles/nix-client-config/` — role (READ ONLY)

## Acceptance Criteria

- [ ] nix.conf deployed on all 5 Nix machines
- [ ] `nix show-config` shows correct substituters with priorities
- [ ] `nix show-config` shows correct trusted-public-keys
- [ ] Test build on LAN machine pulls from Harmonia/ncps cache
- [ ] Test build on cloud machine pulls from cloud ncps/ncro chain
- [ ] Cache miss falls through to cache.nixos.org via ncro

## Test Plan

- nix show-config verification on each machine
- Test build with verbose substitution logging on LAN + cloud machines
- Cache miss fallback test

## Observability

- Nix substitution logs show which cache served each path
- ncro `/health` shows request counts increasing
- ncps logs show NAR cache hits/misses

## Compliance

- No secrets in nix.conf (only public keys)
- Existing nix.conf backed up before overwriting

## Risks & Mitigations

- Risk: Overwriting nix.conf breaks existing Nix operations — Mitigation: Backup existing nix.conf; test on one machine first before deploying to all
- Risk: macOS nix-darwin manages nix.conf — Mitigation: Check if nix-darwin is in use; if so, integrate with nix-darwin config instead
- Risk: Substitution fails (wrong public key, unreachable cache) — Mitigation: Verify Harmonia public key matches signing key; verify Tailscale connectivity to regional ncps
- Risk: Windows Nix doesn't use /etc/nix/nix.conf — Mitigation: Skip Windows or use WSL2 Nix config path

## Dependencies & Sequencing

- Depends on: 03-001 (playbook), 04-001 (cache services must be running)
- Unblocks: None (final story in the chain)

## Definition of Done

- [ ] All verification commands from sub-tasks pass
- [ ] Test builds successfully pull from the new cache chain
- [ ] No code changes (operational task only)

## STOP Conditions

Stop and report if:
- nix.conf deployment fails on any machine
- Substitution doesn't work (wrong public key, unreachable cache)
- nix-darwin is managing nix.conf on macOS (need different approach)
- Windows Nix doesn't support /etc/nix/nix.conf

## Maintenance Notes

- Re-run the playbook with `--tags client-config` to redeploy nix.conf
- When Harmonia signing key is rotated, update nix_harmonia_public_key in defaults/main.yml and redeploy
- When regional hubs change, update infra Tailscale IP variables and redeploy

## Commit Conventions

- No code changes — no commit needed

## Changelog

- 2026-07-08: initialized story file
