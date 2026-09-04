---
story_id: "01-003"
story_title: "Vault secrets handoff for Nix cache chain (user task)"
story_name: "vault-secrets"
prd_name: "nix-cache-chain"
prd_file: "internal-docs/feature/2026/07/nix-cache-chain/feat-202607081745-nix-cache-chain.md"
phase: 1
parallel_id: 3
branch: "feature/current/nix-cache-chain/story-01-003-vault-secrets"
status: "done"
assignee: ""
reviewer: ""
dependencies: []
parallel_safe: true
modules: ["levonk/02-config/ansible/inventories/group_vars"]
priority: "MUST"
risk_level: "medium"
tags: ["feat", "vault", "secrets"]
due: "2026-07-15"
created_at: "2026-07-08"
updated_at: "2026-07-08"
---

## Summary

This is a **user-handoff task**. The agent generates the secret values and provides the user with a copyable `docker run` command to edit the vault file. Per AGENTS.md policy, the agent MUST NOT edit the vault directly. The vault file is at `levonk/active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml`. Secrets needed: Harmonia signing key, Attic HS256 token secret, optional Cachix auth token.

## Current State

- **Relevant files and their roles:**
  - `levonk/active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml` — encrypted vault file (DO NOT decrypt or edit directly)
  - `levonk/active/02-config/ansible/inventories/group_vars/all.yml` — plaintext companion (contains `cuser_name`, `timezone`, etc. — no secrets here)

- **Repository conventions (AGENTS.md Vault Edits policy):**
  - Agent MUST NOT run `ansible-vault edit` (no interactive TTY)
  - Agent MUST NOT decrypt → edit → re-encrypt manually (corruption risk)
  - Agent MUST provide the user with:
    1. The exact YAML line(s) to add
    2. A copyable `docker run` command with paths pre-filled
  - Agent generates secret values (e.g., `openssl rand -hex 32`)
  - Agent waits for user confirmation before proceeding

- **Vault edit command template (from AGENTS.md):**
  ```bash
  docker run --rm -it \
    -v "$HOME/.ansible/vault_password:/vault_password:ro" \
    -v "$HOME/p/gh/levonk/infrahub/levonk/active/02-config/ansible/inventories/group_vars:/vault-dir" \
    -e EDITOR=vi \
    alpine/ansible:latest \
    ansible-vault edit /vault-dir/infrahub-levonk-all.vault.yml --vault-password-file /vault_password
  ```

## Scope

**In scope:**
- Generate Harmonia signing key pair using `nix-store --generate-binary-cache-key`
- Generate Attic HS256 secret using `openssl rand -base64 32`
- Provide user with the vault edit command and YAML lines to add
- Verify vault is accessible after user confirms

**Out of scope:**
- Actually editing the vault file (user does this)
- Deploying services that consume the secrets (Phase 4)

## Sub-Tasks

- [x] Task 1 — Generate Harmonia signing key pair
  Run: `nix-store --generate-binary-cache-key levonk-harmonia-cache-1 /tmp/harmonia-secret-key.sec /tmp/harmonia-public-key.pub`
  The public key will be needed for nix.conf `trusted-public-keys` on all machines. The secret key goes in the vault.
  **Verify**: `cat /tmp/harmonia-public-key.pub` → outputs `levonk-harmonia-cache-1:<BASE64_KEY>`
  Public key: `levonk-harmonia-cache-1:/aImtI+zqbieGranjKNv9nOB8vP3aHAfg5K2wO9+SsQ=`

- [x] Task 2 — Generate Attic HS256 secret
  Run: `openssl rand -base64 32`
  **Verify**: Output is a 44-character base64 string

- [x] Task 3 — Provide user with vault edit instructions
  Present the user with:
  1. The YAML lines to add to the vault:
     ```yaml
     vault_nix_harmonia_sign_key: |
       <contents of /tmp/harmonia-secret-key.sec>
     vault_nix_attic_token_secret: "<openssl rand base64 output>"
     vault_cachix_auth_token: ""  # Optional — only if using Cachix
     ```
  2. The copyable docker run command (from the template above)
  3. Instructions: "Run this command, add the lines above, save and exit"
  **Verify**: User confirms they have added the secrets

- [x] Task 4 — Verify vault is accessible after user confirmation
  **Verify**: `devbox run -- ansible-vault view levonk/active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml --vault-password-file ~/.ansible/vault_password | grep vault_nix_harmonia_sign_key` → line exists (DO NOT print the value)

- [x] Task 5 — Clean up temporary key files
  **Verify**: `rm -f /tmp/harmonia-secret-key.sec /tmp/harmonia-public-key.pub` → exit 0

## Relevant Files

- `levonk/active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml` — vault file (user edits, not agent)

## Acceptance Criteria

- [x] Harmonia signing key pair generated
- [x] Attic HS256 secret generated
- [x] User provided with vault edit command and YAML lines
- [x] User confirms secrets added to vault
- [x] Vault view confirms `vault_nix_harmonia_sign_key` and `vault_nix_attic_token_secret` exist
- [x] Temporary key files cleaned up

## Test Plan

- Vault accessibility: `ansible-vault view` succeeds and contains the new variable names
- No secret values printed in conversation or logs

## Observability

- No metrics changes — this is a secrets provisioning task

## Compliance

- **CRITICAL**: Never print secret values in conversation after user adds them (AGENTS.md Secret Storage Strategy)
- Secrets must only exist in the vault file, never in shared/ or plaintext files
- Temporary key files must be deleted after use

## Risks & Mitigations

- Risk: User unavailable to edit vault — Mitigation: This story blocks Phase 4 deployment; document the blocker and proceed with Phase 2-3 work that doesn't require the actual secret values (roles can reference `vault_nix_harmonia_sign_key` variable name without the value existing yet)
- Risk: Vault corruption during edit — Mitigation: Follow AGENTS.md Vault Troubleshooting section; check git history for working versions if needed

## Dependencies & Sequencing

- Depends on: None (can generate secrets independently)
- Unblocks: Story 02-001 (harmonia role references vault_nix_harmonia_sign_key), Story 02-003 (ncro role may reference Cachix token), Story 02-004 (attic role references vault_nix_attic_token_secret), Story 04-001 (deployment needs actual secret values)

## Definition of Done

- [x] User confirms secrets added to vault
- [x] `ansible-vault view` confirms variable names exist (values not printed)
- [x] Temporary files cleaned up
- [x] No secret values in conversation logs

## STOP Conditions

Stop and report if:
- `nix-store --generate-binary-cache-key` fails (Nix not installed on control machine)
- User is unavailable to edit the vault (proceed with other stories, mark this as blocked)
- Vault file is corrupted and cannot be edited

## Maintenance Notes

- Harmonia signing key rotation requires updating all nix.conf trusted-public-keys on all machines
- The public key (`levonk-harmonia-cache-1:<BASE64>`) must be added to nix.conf trusted-public-keys (handled in Story 02-005)
- Document the public key in the story file or a non-secret reference for the client-config role

## Commit Conventions

- No code changes — this is an operational task. If any documentation is created: `docs(vault): document nix-cache-chain vault secrets`

## Changelog

- 2026-07-08: initialized story file
