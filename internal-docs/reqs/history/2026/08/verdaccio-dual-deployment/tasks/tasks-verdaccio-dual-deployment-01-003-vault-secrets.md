---
story: 01-003
name: vault-secrets
status: "Todo"
depends: ["01-001"]
branch: feature/current/verdaccio-dual-deployment/story-01-003-vault-secrets
---

# Story 01-003: Vault Secrets Handoff

## Goal

Identify required vault secrets for verdaccio and prepare the user handoff for htpasswd credentials.

## Tasks

1. **Identify secrets**:
   - `vault_verdaccio_admin_password` — password for the admin user (for npm publish)
   - `vault_verdaccio_admin_username` — username (default: "levonk-admin")
   - Generate password: `openssl rand -base64 24`

2. **Prepare vault handoff command** (do NOT edit vault directly):
   ```bash
   docker run --rm -it \
     -v ~/.ansible/vault_password:/vault_password:ro \
     -v ~/p/gh/levonk/infrahub/levonk/active/02-config/ansible/inventories/group_vars:/vault-dir \
     -e EDITOR=vi \
     alpine/ansible:latest \
     ansible-vault edit /vault-dir/infrahub-levonk-all.vault.yml --vault-password-file /vault_password
   ```

3. **Tell user what to add**:
   ```yaml
   # Verdaccio NPM Registry
   vault_verdaccio_admin_username: "levonk-admin"
   vault_verdaccio_admin_password: "<generated_value>"
   ```

4. **Reference in role defaults** (will be done in story 01-004):
   ```yaml
   verdaccio_admin_username: "{{ vault_verdaccio_admin_username | default('levonk-admin') }}"
   verdaccio_admin_password: "{{ vault_verdaccio_admin_password | default('') }}"
   ```

## Acceptance Criteria

- [ ] Vault secret names identified and documented
- [ ] Vault handoff command prepared (copyable docker run)
- [ ] User told exactly what YAML lines to add
- [ ] Agent does NOT edit vault directly
- [ ] Agent does NOT print the generated password value in conversation after user adds it

## Implementation Guide

See `.agents/workflows/infrahub-add-new-service.md` Phase 4 (Vault Secrets) and AGENTS.md "Vault Edits (Agent → User Handoff)".

## Blocker

This story produces a user handoff — the agent generates the password, provides the docker run command, and waits for the user to confirm before proceeding. Mark as [!] Blocked after preparing the handoff, with the question being "Please run the docker run command and add the vault entries, then confirm."
