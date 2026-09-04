# Vault Handoff Instructions — no-mistakes Shared Git Gate (Story 04-001)

This file contains the instructions for adding the no-mistakes shared git gate
secrets to the Ansible vault. The agent has generated the SSH key pair and
prepared everything below. **You (the user) must run the docker command and
paste in the YAML lines.**

## SSH Public Key (non-secret, safe to display)

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILs4YydcWJkFpd38KU9HXXTS7O4/F43MyeQzyPSWiSSB no-mistakes-gate@dtop202311
```

This is also saved to `gate-ssh-public-key.txt` in this directory.

## SSH Private Key

The private key was generated to `/tmp/no-mistakes-gate-key` on the agent's
machine. **It is NOT stored in any repo file.** The orchestrator will present
the private key contents to you directly so you can paste it into the vault.

If the `/tmp` key is no longer available, regenerate it with:

```bash
ssh-keygen -t ed25519 -f /tmp/no-mistakes-gate-key -N "" -C "no-mistakes-gate@dtop202311"
```

(Regenerating will produce a different key pair — the public key above would
then need to be updated to match.)

## YAML Lines to Add to the Vault

Add the following lines to the vault file. Replace the placeholders with the
values provided to you by the orchestrator (the private key contents must be
indented by 2 spaces under the `|` literal block indicator):

```yaml
# no-mistakes Shared Git Gate
vault_no_mistakes_github_token: "<USER_MUST_PROVIDE_GITHUB_TOKEN>"
vault_no_mistakes_gate_ssh_private_key: |
  <PASTE_PRIVATE_KEY_CONTENTS_HERE_INDENTED_2_SPACES>
vault_no_mistakes_gate_ssh_public_key: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILs4YydcWJkFpd38KU9HXXTS7O4/F43MyeQzyPSWiSSB no-mistakes-gate@dtop202311"
vault_no_mistakes_devin_api_key: "<USER_MUST_PROVIDE_DEVIN_API_KEY>"
```

### Notes on the placeholders

- **`vault_no_mistakes_github_token`**: You must create a GitHub personal access
  token with `repo` and `workflow` scopes. Paste it between the quotes.
- **`vault_no_mistakes_gate_ssh_private_key`**: Paste the full contents of the
  private key (including the `-----BEGIN/END OPENSSH PRIVATE KEY-----` lines),
  indented by 2 spaces so YAML treats it as a literal block under the `|`.
- **`vault_no_mistakes_gate_ssh_public_key`**: Already filled in above.
- **`vault_no_mistakes_devin_api_key`**: You must provide your Devin/Windsurf
  API key. Paste it between the quotes.

## Docker Run Command to Edit the Vault

Run this command in a terminal. It opens an interactive `ansible-vault edit`
session with `vi`:

```bash
docker run --rm -it \
  -v "$HOME/.ansible/vault_password:/vault_password:ro" \
  -v "$HOME/p/gh/levonk/infrahub/levonk/active/02-config/ansible/inventories/group_vars:/vault-dir" \
  -e EDITOR=vi \
  alpine/ansible:latest \
  ansible-vault edit /vault-dir/infrahub-levonk-all.vault.yml --vault-password-file /vault_password
```

## Steps

1. Run the `docker run` command above.
2. In `vi`, add the YAML lines from the section above (filling in the
   user-provided secrets and the private key contents the orchestrator showed
   you).
3. Save and exit (`Esc` then `:wq`).
4. Verify the secrets were added (names only, not values):

   ```bash
   devbox run -- ansible-vault view levonk/active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml --vault-password-file ~/.ansible/vault_password | grep vault_no_mistakes
   ```

   You should see four variable names:
   - `vault_no_mistakes_github_token`
   - `vault_no_mistakes_gate_ssh_private_key`
   - `vault_no_mistakes_gate_ssh_public_key`
   - `vault_no_mistakes_devin_api_key`

5. Confirm back to the orchestrator that the vault edit is complete.
