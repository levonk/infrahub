# macos-xcode

Install Xcode on macOS hosts via the Mac App Store CLI (`mas`). Auto-selects the target Xcode version based on macOS version and architecture.

## Requirements

- Ansible >= 2.15
- Target host: macOS (Sequoia 15.6+ or Tahoe 26.x)
- `mas` (Mac App Store CLI) in PATH — installed via the nix-darwin fleet module
- An Apple ID signed into the Mac App Store **as the GUI user** (not `auser`)

### Why the GUI user — distributed configuration for Xcode

`mas` requires an Apple ID signed in to the App Store, but:
- `mas signin` is **disabled on macOS 10.13+** (Apple removed the private API)
- 2FA requires GUI interaction — there is no CLI path
- App Store sign-in is **per-macOS-user**, not system-wide

Ansible connects as `auser` (a headless SSH service account with no GUI session). `auser` cannot sign in to the App Store. Instead, the **GUI user** (the user logged in to the macOS GUI session) signs in manually via System Settings → Apple ID, and the xcode role runs `mas` as that user via `become_user`.

Xcode installs to `/Applications/` and is available to **all users** on the Mac — only the sign-in is per-user, the installed app is shared. Other users may get a one-time App Store password prompt when they first launch Xcode (normal macOS behavior for App Store apps installed by a different Apple ID).

**Two-phase flow:**
1. **Phase 1 — bootstrap** (`shared/scripts/bootstrap-macos-manual.sh`, target Mac, human at keyboard):
   - SSH, auser, sudo, SSH key (automated)
   - Apple ID / App Store sign-in for the GUI user (manual, GUI only — the script opens System Settings → Apple ID automatically)
2. **Phase 2 — Ansible** (control Mac, unattended):
   - nix-darwin apply (installs `mas` and other fleet tools)
   - `mas` installs Xcode as the GUI user (unattended, ~12GB download)
   - License accept + `xcode-select` (as root, unattended)

### Multi-user sign-in check

The role checks **all human users** (UID >= 501) on the Mac in priority order:
1. `macos_gui_user` if set in inventory (explicit override)
2. `auser` (the Ansible service account — unlikely but checked)
3. GUI user (`stat -f%Su /dev/console` — whoever is logged in to the GUI)
4. All other human users

The **first signed-in user** wins. This means any user on the Mac being signed in to the App Store is sufficient — it doesn't have to be the GUI user or a specific account. Xcode installs to `/Applications/` and is shared with all users.

To override auto-detection, set `macos_gui_user` in the inventory:

```yaml
# levonk/active/02-config/ansible/inventories/macos-hosts.yml
macos_hosts:
  vars:
    macos_gui_user: "micro"  # uncomment to override auto-detection
```

### Non-fatal error handling

If mas is not available or no user is signed in to the App Store, the role **does not hard-fail**. Instead:
- Prints 🚨 with a clear message
- Skips the mas install (Xcode won't be installed)
- Continues with Command Line Tools fallback (if enabled)
- Lists all errors in the summary at the end of the run

This allows the rest of `configure-macos-host.yml` to complete. To install Xcode later, sign in to the App Store and re-run `just ansible-install-xcode`.

## Version Selection

The role auto-detects the target Xcode version based on the host's macOS version and architecture:

| macOS Version | Architecture | Target Xcode | Source |
|---------------|-------------|-------------|--------|
| Sequoia 15.6+ | x86_64 (Intel) | 26.3 | Hardcoded — terminal version for Intel (no Tahoe support) |
| Sequoia 15.6+ | arm64 (Apple Silicon) | 26.3 | Hardcoded — latest Sequoia-compatible |
| Tahoe 26.x+ | arm64 | Latest in App Store | **Dynamic lookup** via iTunes Search API |

### Dynamic lookup (Tahoe+ hosts)

For macOS Tahoe (26.x) and later, the role queries the iTunes Search API (`https://itunes.apple.com/lookup?id=497799835`) to get the latest Xcode version and its `minimumOsVersion`. If the host's macOS version meets the minimum requirement, the API version is used. If the API is unreachable or the latest version requires a newer macOS than the host has, it falls back to `macos_xcode_version_tahoe_fallback`.

Sequoia hosts always use the hardcoded `26.3` — the latest Xcode in the App Store requires Tahoe, so a dynamic lookup would always reject Sequoia.

Disable the dynamic lookup with:

```yaml
macos_xcode_lookup_latest: false
```

Override the auto-detection entirely by setting `macos_xcode_target_version`:

```yaml
macos_xcode_target_version: "26.3"
```

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `macos_xcode_target_version` | `""` (auto-detect) | Force a specific Xcode version |
| `macos_xcode_version_sequoia` | `"26.3"` | Xcode version for macOS Sequoia (hardcoded — terminal for Intel) |
| `macos_xcode_version_tahoe_fallback` | `"26.3"` | Fallback for Tahoe if API lookup fails or is incompatible |
| `macos_xcode_lookup_latest` | `true` | Query iTunes API for latest version on Tahoe+ hosts |
| `macos_xcode_itunes_lookup_url` | `https://itunes.apple.com/lookup?id=497799835` | iTunes Search API endpoint |
| `macos_xcode_lookup_timeout` | `15` | API request timeout (seconds) |
| `macos_xcode_mas_app_id` | `"497799835"` | Mac App Store app ID for Xcode |
| `macos_xcode_mas_user` | `{{ macos_gui_user \| default('') }}` (auto-detected) | macOS user to run mas as (GUI user with App Store sign-in). Auto-detected via `stat -f%Su /dev/console` if `macos_gui_user` is not set. |
| `macos_xcode_accept_license` | `true` | Accept Xcode license after install |
| `macos_xcode_select_xcode` | `true` | Switch xcode-select to installed Xcode |
| `macos_xcode_install_clt_fallback` | `true` | Install CLT if Xcode install fails/skips |
| `macos_xcode_mas_path` | `"mas"` | Path to mas binary |

## Dependencies

None. However, `mas` must be available in PATH — it is installed by the nix-darwin fleet module (`environment.systemPackages`). Run `configure-macos-host.yml` (which applies the nix-darwin flake) before this role, or ensure `mas` is installed separately.

## Example Playbook

```yaml
- hosts: macos_hosts
  become: false
  roles:
    - role: macos-xcode
      tags: ["xcode", "dev-tools"]
```

## Usage

### Via just recipe

```bash
just ansible-install-xcode
```

### Via ansible-playbook directly

```bash
ansible-playbook -i levonk/active/02-config/ansible/inventories/macos-hosts.yml \
  shared/active/02-config/ansible/playbooks/configure-macos-host.yml \
  --vault-password-file ~/.ansible/vault_password \
  --tags xcode
```

## Notes

- **Apple ID sign-in is interactive and per-user.** `mas` cannot automate Apple ID authentication (`mas signin` is disabled on macOS 10.13+, and 2FA requires GUI interaction). Any user on the Mac must sign in via System Settings → Apple ID before running this role. The `bootstrap-macos-manual.sh` script checks all users and opens System Settings automatically.
- **mas runs as the first signed-in user, not `auser`.** Ansible connects as `auser` (SSH service account), but mas commands run via `become_user: {{ macos_xcode_mas_user }}` because App Store sign-in is per-macOS-user and `auser` has no GUI session. The role checks all human users (auser, GUI user, then others) and uses the first one signed in. Xcode installs to `/Applications/` and is shared with all users.
- **Non-fatal errors.** If mas is not available or no user is signed in, the role does NOT hard-fail. It prints 🚨, skips mas install, continues with CLT fallback, and lists errors in the summary. This allows the rest of the playbook to complete.
- **Other users may get a launch prompt.** When a different macOS user launches Xcode for the first time, macOS may prompt for the purchasing Apple ID's password (normal behavior for App Store apps installed by a different Apple ID). This is a one-time prompt per user.
- **Xcode is large (~12GB).** The download may take a long time depending on network speed.
- **Idempotent.** If Xcode is already installed at the target version, the role skips all install tasks.
- **Intel Macs are capped at Xcode 26.3.** macOS Tahoe (26.x) does not support Intel, so Xcode 26.3 is the terminal version for x86_64-darwin.
