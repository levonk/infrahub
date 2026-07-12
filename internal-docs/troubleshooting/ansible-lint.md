# Troubleshooting: ansible-lint

Common failures when running `devbox run -- just ansible-lint-internal` or `devbox run -- ansible-lint --offline <path>`.

## Role Naming Convention

All hardening roles follow the pattern `common-{platform}-{concern}-hardening` in the **directory name**, with `role_name: common_{platform}_{concern}_hardening` (underscores) in `meta/main.yml` to satisfy ansible-lint's `role-name` rule.

| Directory | `role_name` in meta |
|---|---|
| `common-ssh-hardening/` | `common_ssh_hardening` |
| `common-windows-ssh-hardening/` | `common_windows_ssh_hardening` |
| `common-windows-rdp-hardening/` | `common_windows_rdp_hardening` |
| `common-hosts-blocklist/` | `common_hosts_blocklist` |

Other roles use functional-group prefixes (`dns-`, `proxy-`, `vpn-`, `ai-`) and set `role_name` with underscores the same way.

### Windows platform versions in meta

The ansible-lint schema rejects `"10"` and `"11"` as Windows platform versions. Valid values are `"6.1"`, `"7.1"`, `"7.2"`, or `"all"`. Always use:

```yaml
platforms:
  - name: Windows
    versions: ["all"]
```

### Enterprise Linux (Oracle Linux) in meta

The OCI cloud server runs Oracle Linux (RedHat family). Use the `EL` platform name, not `RedHat` or `OracleLinux`:

```yaml
platforms:
  - name: EL
    versions: ["8", "9"]
```

## yamllint Config Crashes ansible-lint

ansible-lint delegates YAML validation to yamllint. If the user-level `~/.config/yamllint/config` has invalid entries, ansible-lint crashes with a traceback before it can lint anything.

### Rule values must be dicts, not bare strings

yamllint 1.37+ rejects bare-string rule values. This crashes:

```yaml
# ❌ WRONG — crashes ansible-lint
key-ordering: warning
document-end: warning
```

Use a dict with `level:`:

```yaml
# ✅ CORRECT
key-ordering:
  level: warning
document-end:
  level: warning
```

### Invalid rule names

These are NOT valid yamllint rule names and cause a config validation crash — do not re-add them:

- `new-line-character` (use `new-lines` instead)
- `separators` (removed in yamllint 1.35+)
- `spaces` (removed in yamllint 1.35+)

### check-multi-line-strings

`check-multi-line-strings: true` checks indentation inside block scalars (`|`). Ansible embeds PowerShell/bash scripts via block scalars, and yamllint checks their indentation as YAML, producing false positives on every `win_shell`/`shell` task. Always set:

```yaml
indentation:
  level: error
  check-multi-line-strings: false
  indent-sequences: consistent
```

## Project .ansible-lint.yml skip_list

The project `.ansible-lint.yml` skips these yaml sub-rules because they conflict with Ansible's YAML conventions:

- `yaml[key-ordering]` — Ansible tasks use conventional key order (name, module, when, tags), not alphabetical
- `yaml[document-end]` — Ansible YAML files don't use `...` document terminators
- `yaml[line-length]` — Allow longer lines for readability
- `jinja[spacing]` — Allow flexible Jinja2 spacing
- `name[casing]` — Some role names use hyphens for functional-group prefixes
- `no-changed-when` — Allow commands without `changed_when` for idempotent operations

If a new role fails ansible-lint with `yaml[key-ordering]` or `yaml[document-end]` violations, check whether `.ansible-lint.yml` was modified to remove these skips.

## Pre-existing violations in other roles

Some existing roles have violations that are NOT related to new changes:

- `docker-engine/tasks/main.yml` — trailing spaces (5 occurrences)
- `nix-installation/tasks/main.yml` — trailing spaces (8 occurrences), `command-instead-of-module` (tar used instead of unarchive)
- `vpn-tailscale/tasks/main.yml` — `command-instead-of-shell` (Get NordVPN container IP address)
- `openlit-gpu-collector/meta/main.yml` — missing document start `---`
- `common-ssh-hardening/tests/test.yml` — `syntax-check` fails when linting the role in isolation (references `../common-ssh-hardening` which can't be resolved outside the roles directory)

These are pre-existing and should not block new work. Run ansible-lint on your specific role/playbook to verify your changes:

```bash
devbox run -- ansible-lint --offline shared/active/02-config/ansible/roles/common-hosts-blocklist/
```

## Verification

After fixing lint issues, verify with:

```bash
# Lint a specific role
devbox run -- ansible-lint --offline shared/active/02-config/ansible/roles/<role-name>/

# Lint a specific playbook
devbox run -- ansible-lint --offline shared/active/02-config/ansible/playbooks/<playbook>.yml

# Syntax check
devbox run -- ansible-playbook --syntax-check -i <inventory> <playbook>

# Full lint (may show pre-existing violations in other roles)
devbox run -- just ansible-lint-internal
```
