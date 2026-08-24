---
story_id: "04-001"
story_title: "Vault secrets (user handoff)"
story_name: "vault-secrets"
prd_name: "no-mistakes-shared-gate"
prd_file: "internal-docs/feature/todo/no-mistakes-shared-gate/feat-202608231257-no-mistakes-shared-gate.md"
phase: 4
parallel_id: 1
branch: "feature/current/no-mistakes-shared-gate/story-04-001-vault-secrets"
status: "todo"
assignee: ""
reviewer: ""
dependencies: []
parallel_safe: true
modules: ["vault", "secrets"]
priority: "MUST"
risk_level: "medium"
tags: ["vault", "secrets", "handoff"]
due: "2026-08-23"
create-date: "2026-08-23"
update-date: "2026-08-23"
---

## Summary

Generate and prepare vault secrets for the no-mistakes service. The agent MUST NOT edit the vault directly — provide the user with a copyable `docker run` command and the exact YAML lines to add.

## Sub-Tasks

- [ ] Generate SSH key pair for gate user:
  ```bash
  ssh-keygen -t ed25519 -f /tmp/no-mistakes-gate-key -N "" -C "no-mistakes-gate@dtop202311"
  ```
- [ ] Generate GitHub token (user must create this — needs `repo` and `workflow` scopes)
- [ ] Prepare Devin/Windsurf API key reference (user must provide)
- [ ] Provide user with the copyable `docker run` command to edit the vault:
  ```bash
  docker run --rm -it \
    -v "$HOME/.ansible/vault_password:/vault_password:ro" \
    -v "$HOME/p/gh/levonk/infrahub/levonk/active/02-config/ansible/inventories/group_vars:/vault-dir" \
    -e EDITOR=vi \
    alpine/ansible:latest \
    ansible-vault edit /vault-dir/infrahub-levonk-all.vault.yml --vault-password-file /vault_password
  ```
- [ ] Tell user to add these lines to the vault:
  ```yaml
  # no-mistakes Shared Git Gate
  vault_no_mistakes_github_token: "<USER_PROVIDED_GITHUB_TOKEN>"
  vault_no_mistakes_gate_ssh_private_key: |
    <CONTENTS_OF_/tmp/no-mistakes-gate-key>
  vault_no_mistakes_gate_ssh_public_key: "<CONTENTS_OF_/tmp/no-mistakes-gate-key.pub>"
  vault_no_mistakes_devin_api_key: "<USER_PROVIDED_DEVIN_API_KEY>"
  ```
- [ ] Wait for user confirmation before proceeding

## Relevant Files

- `levonk/active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml` — Vault file (user edits)

## Acceptance Criteria

- Given the vault file, When the user has added the secrets, Then `vault_no_mistakes_github_token`, `vault_no_mistakes_gate_ssh_private_key`, `vault_no_mistakes_gate_ssh_public_key`, and `vault_no_mistakes_devin_api_key` are defined
- Given the SSH key pair, When testing, Then the private key can authenticate with the public key

## Test Plan

- User confirms vault edit complete
- `devbox run -- ansible-vault view levonk/active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml --vault-password-file ~/.ansible/vault_password | grep vault_no_mistakes` shows the new variables (names only, not values)

## Definition of Done

User confirms vault secrets added. Agent does NOT print secret values.

## Implementation Guide Reference

Follows `infrahub-add-new-service.md` Phase 4 (4a Identify, 4b Add to vault, 4c Reference in role defaults).
Follows AGENTS.md "Vault Edits (Agent → User Handoff)" policy.
