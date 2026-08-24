# Buzz Agent Runtime — Developer Reference

How to add, configure, and manage Buzz agent runtime containers.

## Architecture

```
Buzz clients (desktop/web/CLI)
    ↕ WebSocket
Buzz relay (buzz.levonk.com, already deployed)
    ↕ WebSocket (internal buzz-network)
buzz-agent-<id> containers (one per agent)
    ↕ spawns via stdio
  devin acp (Devin CLI ACP runtime)
```

Each agent is a Docker container running `buzz-acp`, which spawns `devin acp` as
its ACP subprocess. The agent connects to the relay using its own Nostr
identity (keypair) and listens for @mentions in channels it's a member of.

**Network topology**: Agents join both `buzz-network` and `traefik-network`.
They connect to the relay via `wss://buzz.levonk.com` (through Traefik), not
via the internal `ws://buzz:3000` address. This is required because the relay
validates that the URL in the NIP-42 auth event matches its configured
`RELAY_URL` (`wss://buzz.levonk.com`). A Traefik WebSocket bypass router
(`buzz-agent-ws.yml` in Traefik's dynamic config) skips Authelia for WebSocket
upgrade requests and `/query` API calls, so agents can authenticate via NIP-42
without SSO credentials. The `buzz.levonk.com` hostname is resolved via
`/etc/hosts` inside each container, pointing to Traefik's IP on
`traefik-network`.

**Key principle**: one container per agent. Each agent has:
- Its own Nostr keypair (identity)
- Its own `buzz-acp` process (harness)
- Its own `devin acp` subprocess (AI runtime)
- Isolation from other agents (each can run arbitrary shell commands)

## Adding a New Agent

### 1. Generate a Nostr keypair

```bash
python3 -c "
import secrets
CHARSET = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l'
def bech32_polymod(values):
    GEN = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3]
    chk = 1
    for v in values:
        b = chk >> 25; chk = (chk & 0x1ffffff) << 5 ^ v
        for i in range(5): chk ^= GEN[i] if ((b >> i) & 1) else 0
    return chk
def bech32_hrp_expand(hrp):
    return [ord(x) >> 5 for x in hrp] + [0] + [ord(x) & 31 for x in hrp]
def bech32_create_checksum(hrp, data):
    values = bech32_hrp_expand(hrp) + data
    polymod = bech32_polymod(values + [0,0,0,0,0,0]) ^ 1
    return [(polymod >> 5 * (5 - i)) & 31 for i in range(6)]
def bech32_encode(hrp, data):
    combined = data + bech32_create_checksum(hrp, data)
    return hrp + '1' + ''.join([CHARSET[d] for d in combined])
def convertbits(data, frombits, tobits, pad=True):
    acc = 0; bits = 0; ret = []; maxv = (1 << tobits) - 1
    for value in data:
        acc = (acc << frombits) | value; bits += frombits
        while bits >= tobits: bits -= tobits; ret.append((acc >> bits) & maxv)
    if pad and bits: ret.append((acc << (tobits - bits)) & maxv)
    return ret
privkey = secrets.token_bytes(32)
data = convertbits(list(privkey), 8, 5)
print(bech32_encode('nsec', data))
"
```

Save the output `nsec1...` string — this is the agent's private key. The
corresponding public key can be derived but is not needed for deployment.

### 2. Add the nsec to the vault

Provide the user with this command to add the secret:

```bash
docker run --rm -it \
  -v "$HOME/.ansible/vault_password:/vault_password:ro" \
  -v "$HOME/p/gh/levonk/infrahub/levonk/active/02-config/ansible/inventories/group_vars:/vault-dir" \
  -e EDITOR=vi \
  alpine/ansible:latest \
  ansible-vault edit /vault-dir/infrahub-levonk-all.vault.yml --vault-password-file /vault_password
```

Add this line (replace `<agent_id>` and `<nsec_value>`):

```yaml
vault_buzz_agent_<agent_id>_nsec: "<nsec1...>"
```

### 3. Register the agent in the inventory

Add the agent to `ai_buzz_agent_agents` in the client group_vars or host_vars:

```yaml
ai_buzz_agent_agents:
  - id: "<agent-id>"          # kebab-case, used in container name
    name: "<Display Name>"    # human-readable
    nsec: "{{ vault_buzz_agent_<agent_id>_nsec }}"
    model: "glm-5-2"          # optional, defaults to ai_buzz_agent_model
```

### 4. Register the agent pubkey as a relay member

The agent's pubkey must be registered as a relay member so it can connect.
Generate the pubkey from the nsec, then use `buzz-admin`:

```bash
# On the OCI server, inside the buzz container:
docker exec buzz buzz-admin add-member --pubkey <agent_pubkey_hex>
```

Or from a machine with the Buzz source:

```bash
cargo run -p buzz-admin -- add-member --pubkey <agent_pubkey_hex> \
  --relay-url ws://buzz:3000 --private-key <relay_signing_key>
```

### 5. Deploy

```bash
devbox run -- ansible-playbook \
  -i levonk/active/02-config/ansible/inventories/oci.yml \
  shared/active/02-config/ansible/playbooks/deploy-buzz-agents.yml \
  --vault-password-file ~/.ansible/vault_password
```

### 6. Create channels and add the agent

From a Buzz client (desktop, web, or CLI):
1. Create a channel (or use an existing one)
2. Add the agent's pubkey as a channel member
3. @mention the agent to start a conversation

## Devin CLI Authentication

All agents share the same Devin account credentials. The credentials file is
mounted read-only into each container at
`/home/agent/.local/share/devin/credentials.toml`.

**To place credentials on the host:**

```bash
# On the OCI server:
sudo mkdir -p /srv/localnet/buzz-agent
sudo cp credentials.toml /srv/localnet/buzz-agent/devin-credentials.toml
sudo chown 1000:1000 /srv/localnet/buzz-agent/devin-credentials.toml
sudo chmod 600 /srv/localnet/buzz-agent/devin-credentials.toml
```

The credentials file is NOT stored in the vault (it's a binary-format TOML with
session tokens, not a simple key-value). It's placed directly on the host
filesystem and mounted read-only into each container.

**Security**: The credentials file grants access to the Devin account. Protect
it with filesystem permissions (owner-only read). All agents share the same
Devin Pro quota — concurrent usage draws from the same pool.

## Telemetry

Telemetry is disabled at two levels:

1. **Account level** (server-side, enforced): The Devin account has
   `Telemetry: disabled (zero-data-retention)`. This cannot be overridden by
   the client.

2. **Client config** (baked into the Docker image): The `config.json` in the
   image sets:
   - `attribution: false` — no Devin branding in commits/PRs
   - `auto_update: false` — pinned container, no background updates
   - `show_hints: false` — no tip notifications
   - `notify: "never"` — no terminal notifications
   - `subagents_enabled: false` — one agent per container, no nesting

**Note on Unleash feature-flag polling**: The Devin CLI includes a feature-flag
system (Unleash) that polls for flag values on startup. The logs show
`unleash flags evaluated: ... (user_id=false team_id=false)` — no user or team
identification is sent. The analytics subsystem initializes and immediately
closes (`analytics_new: close time.busy=...`). This is the maximum telemetry
disablement achievable without modifying the Devin binary. The Unleash polling
is a feature-flag mechanism, not usage tracking.

A per-agent config template is also available at
`templates/devin-config.json.j2` if per-agent model overrides are needed.

## Model Selection

The model is controlled by the `DEVIN_MODEL` environment variable, set per-agent
via the `model` field in `ai_buzz_agent_agents`. Models use an indirection chain
so the free model can be changed in one place:

```
per-agent model (override)        ← set in inventory per agent if needed
  → ai_buzz_agent_model           ← role default (defaults to free_model)
    → free_model                  ← global default for all free-tier services
      → free_model_devin          ← the current free Devin model (change here)
```

**To change the free model for all services**: edit `free_model_devin` in
`shared/active/02-config/ansible/infrastructure/models.yml`. Every service that
defaults to `free_model` inherits the change.

**To override for a specific agent**: set `model:` explicitly in the agent entry.

**To override for all buzz agents only**: set `ai_buzz_agent_model` in the
inventory group_vars.

All agents currently inherit the global free model (no per-agent overrides).
Model selection belongs to the Devin ACP process, not the relay. The relay is
model-agnostic.

## Removing an Agent

1. Remove the agent from `ai_buzz_agent_agents` in the inventory
2. Run the deploy playbook (the container will be stopped/removed)
3. Remove the agent's relay membership:
   ```bash
   docker exec buzz buzz-admin remove-member --pubkey <agent_pubkey_hex>
   ```
4. Optionally remove the nsec from the vault

## Troubleshooting

### Agent container won't start

Check logs:
```bash
docker logs buzz-agent-<id> --tail 50
```

Common issues:
- Missing `BUZZ_PRIVATE_KEY` — check the vault variable is defined
- Invalid nsec format — must start with `nsec1`
- Relay unreachable — verify the relay container is running: `docker ps | grep buzz`
- Devin credentials missing — check the mount path exists on the host

### Agent connects but doesn't respond to mentions

- Verify the agent pubkey is registered as a relay member
- Verify the agent is a member of the channel you're mentioning it in
- Check `docker logs buzz-agent-<id>` for ACP errors
- Verify `devin acp` is working: `docker exec buzz-agent-<id> devin --version`

### Devin quota exhausted

All agents share the same Devin Pro quota. If one agent exhausts the quota,
all agents will fail until the quota resets. Monitor usage at
https://app.devin.ai/settings/usage.

## File Reference

| File | Purpose |
|------|---------|
| `roles/ai-buzz-agent/defaults/main.yml` | Default variables (image, network, model, agent list) |
| `roles/ai-buzz-agent/tasks/main.yml` | Deployment tasks (validate, pull, deploy containers) |
| `roles/ai-buzz-agent/handlers/main.yml` | Restart handler |
| `roles/ai-buzz-agent/meta/main.yml` | Galaxy metadata |
| `roles/ai-buzz-agent/templates/devin-config.json.j2` | Per-agent Devin config template |
| `playbooks/deploy-buzz-agents.yml` | Deployment playbook |
| `services/ai-codeassist/buzz-agent/docker/Dockerfile.buzz-agent` | Container image definition |
| `infrastructure/ports.yml` | Port schema (no host ports for agents) |
| `infrastructure/networks.yml` | Network schema (buzz-network IP range) |
| `infrastructure/storage.yml` | Storage schema (credentials path) |
| `infrastructure/services.yml` | Service catalog entry |
