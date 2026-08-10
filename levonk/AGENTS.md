# Levonk - Private Client Submodule

## CRITICAL: THIS IS A PRIVATE CLIENT SUBMODULE

**This repository is a git submodule of the infrahub project and contains CLIENT-SPECIFIC sensitive information.**

## Architecture Context

- **Parent Repository**: `~/p/gh/levonk/infrahub`
- **Purpose**: Private overlay for the levonk client infrastructure
- **Content**: Client-specific configurations, secrets, and customizations
- **Security Level**: PRIVATE - Contains sensitive information

## CRITICAL RULES

### 1. NEVER Convert to Regular Directory
- **NEVER** delete the git submodule and replace it with a regular directory
- **NEVER** treat this as a normal directory in the parent repo
- **ALWAYS** maintain proper git submodule structure
- **ALWAYS** use `git submodule` commands for updates

### 2. Secret Storage Location (ADR-20260624001)
- **✅ CORRECT**: Store secrets in `active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml`
- **❌ FORBIDDEN**: Store secrets in parent repo's `shared/` directory
- **❌ FORBIDDEN**: Store secrets in plaintext anywhere
- **ALWAYS** use Ansible vault encryption for secrets

### 3. No Secrets in Shared Directory
The parent repo's `shared/` directory must NEVER contain client-specific secrets:
- No vault files in `shared/`
- No hardcoded secrets in `shared/` service definitions
- All secrets must use vault variable references
- Client-specific configurations only in this submodule (`levonk/`)

**Public-key exception (ADR-20260624001 §4):** Public SSH keys are non-secret and may be embedded in `shared/scripts/bootstrap-*.sh` / `.ps1` as defaults. The operator-owned admin bootstrap key (`lzkmbp2016-micro-oracle`) is repo-wide, not client-specific — it bootstraps `auser` on every client's hosts, and a fresh host cannot clone the client submodule to read a key path until it has been bootstrapped. Client-specific keys (per-client CI deploy keys, per-client service accounts) still belong in this submodule.

## Submodule Workflow

### Updating This Submodule
```bash
# From the parent infrahub directory
cd ~/p/gh/levonk/infrahub

# Update submodule to latest
git submodule update --remote levonk

# Commit the submodule update
git add levonk
git commit -m "Update levonk submodule to latest"
```

### Working Within This Submodule
```bash
# Enter the submodule directory
cd levonk

# Make changes
git add .
git commit -m "Description of changes"
git push origin master

# Return to parent and update reference
cd ..
git add levonk
git commit -m "Update levonk submodule reference"
```

## Integration with Parent Repo

### Proper Workflow
1. Make changes in this submodule (levonk/)
2. Commit and push to levonk master branch
3. Return to parent infrahub repo
4. Update submodule reference: `git submodule update --remote levonk`
5. Commit the submodule update in parent repo

### Forbidden Workflow
❌ **NEVER** make changes to levonk/ files from the parent repo without entering the submodule
❌ **NEVER** delete the submodule and replace with regular directory
❌ **NEVER** move secrets from this submodule to parent's shared/ directory

## File Structure

```
levonk/
├── active/
│   ├── 02-config/ansible/
│   │   ├── inventories/
│   │   │   ├── group_vars/
│   │   │   │   └── infrahub-levonk-all.vault.yml  # CLIENT SECRETS HERE
│   │   │   └── oci.yml                             # Client inventory
│   │   └── host_vars/
│   │       └── oci-cloud-server.yml               # Client host config
│   └── 08-docs/
│       └── adr/                                    # Client-specific docs
└── AGENTS.md                                       # THIS FILE
```

## Security Principles

1. **Client Isolation**: Each client has their own submodule with isolated secrets
2. **Shared Path Clean**: Parent repo's shared/ directory contains no client secrets
3. **Proper Submodule**: Maintain git submodule structure for clean separation
4. **Vault Encryption**: All secrets encrypted with Ansible vault

## macOS System Configuration (nix-darwin)

Levonk's macOS hosts (`lzkmbp2016`, `lzkmbp2018`) are configured via **nix-darwin**, not Ansible alone. The architecture follows the client isolation principle (ADR-20260624001):

- **Shared modules** (generic, non-client-specific) live in `shared/active/02-config/nix/darwin/modules/`
- **Client-specific host configs** and the `darwinConfigurations` flake live in **this submodule** (`levonk/active/02-config/nix/darwin/`)

```
shared/active/02-config/nix/darwin/       # Generic module library (no host names)
├── flake.nix              # Exports modules.* (no darwinConfigurations)
├── modules/system/        # system.defaults, homebrew (empty casks)
├── modules/nix/           # nix.settings, substituters
├── modules/security/      # privacy defaults (SubmitDiagInfo, Safari, etc.)
├── modules/fleet/         # auser admin user, container runtime, fleet apps
└── modules/networking/    # IP forwarding, exit node config

levonk/active/02-config/nix/darwin/       # Client-specific host configs
├── flake.nix              # darwinConfigurations.lzkmbp2016, lzkmbp2018
└── hosts/
    ├── lzkmbp2016.nix     # Intel x86_64 Mac config
    └── lzkmbp2018.nix     # Intel x86_64 Mac config
```

### Three-Layer Split

| Layer | Tool | What it manages | Where it lives |
|-------|------|-----------------|----------------|
| System-level (shared) | nix-darwin | system.defaults, privacy, homebrew, nix settings, fleet apps | `shared/active/02-config/nix/darwin/modules/` |
| System-level (client) | nix-darwin | host-specific configs, darwinConfigurations | `levonk/active/02-config/nix/darwin/` |
| Sudo non-defaults | Ansible | pmset, chflags (things nix-darwin can't do) | `shared/active/02-config/ansible/playbooks/configure-macos-host.yml` |
| User-level | chezmoi | ~130 user defaults (dock size, keyboard, etc.) | `dotfiles/home/current/dot_local/bin/executable_osx-settings.py` |

### Applying macOS System Config

```bash
# From the infrahub root, on the Mac you want to configure:
cd ~/p/gh/levonk/infrahub
sudo nix --extra-experimental-features 'nix-command flakes' run nix-darwin \
  -- switch --flake ./levonk/active/02-config/nix/darwin#<hostname>

# Rollback to previous generation:
sudo darwin-rebuild rollback

# List available generations:
darwin-rebuild generations
```

### Adding a New macOS Host

1. Create `levonk/active/02-config/nix/darwin/hosts/<hostname>.nix`
2. Add `darwinConfigurations.<hostname> = ...` to `levonk/active/02-config/nix/darwin/flake.nix`
3. Run `nix flake check ./levonk/active/02-config/nix/darwin` to verify
4. Apply with the command above

### Verification

A verification script exists at:
`internal-docs/feature/2026/07/nix-darwin-use/tasks/verify-01-002-local-validation.sh`

It runs all acceptance criteria (flake check, darwin-rebuild switch, idempotency, defaults read spot-checks, rollback). Run it on the Mac you're configuring.

### Key Decisions

- **No home-manager** (NFR-5): nix-darwin manages system-level only; chezmoi owns the home directory
- **Fleet apps via Nix, not casks** (FR-5): orbstack, rustdesk, etc. in `environment.systemPackages`, not Homebrew casks
- **OS auto-updates OFF** (FR-6): lzkmbp2016 runs OpenCore; automatic OS updates would break it
- **No secrets in the flake** (NFR-2): auser password stays vault-owned

### PRD

Full feature spec: `internal-docs/feature/2026/07/nix-darwin-use/feat-202607060157-nix-darwin-migration.md`

## DNS & DDNS Rollout

Levonk uses the shared two-layer DNS architecture. See `shared/active/02-config/ansible/AGENTS.md` → "DNS Architecture (Two-Layer)" for the full feature documentation.

### Layer 1: CNAME → Tailscale FQDN (Deployed)

All service domains are CNAMEs to `oci.tale-grouper.ts.net` (the OCI cloud server's Tailscale FQDN). Managed by `configure-cloudflare-dns.yml`. The `kckinai.levonk.com` domain is a CNAME to `kckinai.tale-grouper.ts.net` (the inference host).

**Tailscale FQDN variables** (in `levonk/active/02-config/ansible/infrastructure/domains.yml`):
- `infra_tailscale_tailnet`: `tale-grouper.ts.net`
- `infra_tailscale_fqdn_cloud_server`: `oci.tale-grouper.ts.net`
- `infra_tailscale_fqdn_inference_host`: `kckinai.tale-grouper.ts.net`

### Layer 2: DDNS → Public IP (Deployed)

Each Tailscale-attached host runs a `cloudflare-ddns` container that updates a Cloudflare A record with the host's public IP every 5 minutes. Managed by `deploy-cloudflare-ddns.yml`.

**Deployed hosts:**

| Host | DDNS hostname | Record | Public IP |
|------|--------------|--------|-----------|
| `oci-cloud-server` | `oci` | `oci.mach.levonk.com` | Auto-detected |
| `kckinai` | `kckinai` | `kckinai.mach.levonk.com` | Auto-detected |

**Per-host config** (in inventory vars):
- `oci.yml` → `cloudflare_ddns_hostname: "oci"` (under `cloud_servers.vars`)
- `localnet.yml` → `cloudflare_ddns_hostname: "kckinai"` (under `localnet_hosts.vars`)

**To add a new host to the DDNS rollout:**
1. Set `cloudflare_ddns_hostname: "<hostname>"` in the host's inventory vars
2. Run `deploy-cloudflare-ddns.yml` targeting that host
3. Verify: `dig +short <hostname>.mach.levonk.com A`

## ADR Compliance

This submodule follows [ADR-20260624001: Hybrid Sensitive Information Storage Strategy](../shared/active/08-docs/adr/adr-20260624001-hybrid-sensitive-information-storage.md):

- ✅ Per-client central vault in client submodule
- ✅ Shared path clean of client secrets
- ✅ Ansible variable distribution
- ✅ Proper secret isolation

## Troubleshooting

### Submodule Issues
```bash
# If submodule is in detached HEAD state
cd levonk
git checkout master

# If submodule is out of sync
cd ..
git submodule update --init --recursive levonk

# If submodule reference is broken
git submodule sync levonk
git submodule update --init levonk
```

### Secret Access
```bash
# View vault contents (from parent repo)
ansible-vault view levonk/active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml \
  --vault-password-file ~/.ansible/vault_password
```

### Vault Troubleshooting

**Vault Corruption Issues:**
If you encounter "Vault format unhexlify error: Odd-length string" or similar vault decryption errors:

1. **Check git history for working versions:**
   ```bash
   cd levonk
   git log --oneline --all -- active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml
   ```

2. **Restore from a known good commit:**
   ```bash
   git show <commit-hash>:active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml > /tmp/working-vault.yml
   cp /tmp/working-vault.yml active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml
   ```

3. **Verify vault accessibility:**
   ```bash
   cd ~/p/gh/levonk/infrahub
   devbox run -- ansible-vault view levonk/active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml \
     --vault-password-file ~/.ansible/vault_password
   ```

4. **Common vault issues:**
   - **Odd-length hex strings**: File was corrupted during creation/editing
   - **Mixed format**: File contains both encrypted content and inline encrypted values
   - **Wrong password**: Vault password file doesn't match the encryption key
   - **Version mismatch**: Ansible version incompatibility with vault format

## Contact

For questions about this submodule's structure or secret management, refer to the parent repo's AGENTS.md and the ADR document.