# Windows Development: Ansible Roles for Windows Hosts

Developer guide for writing and maintaining Ansible roles that target Windows hosts (dtop202311 — Windows Docker Desktop).

## Windows Module Gaps

The `ansible.windows` collection does NOT have feature parity with `ansible.builtin`. Key gaps:

### No `win_blockinfile`

`ansible.builtin.blockinfile` has no Windows equivalent. For marked-block file management on Windows (e.g., hosts file edits), use `ansible.windows.win_shell` with a PowerShell script that removes and re-inserts the block between markers:

```yaml
- name: "Manage marked block in Windows file"
  ansible.windows.win_shell: |
    $path = "C:\\Windows\\System32\\drivers\\etc\\hosts"
    $begin = '{{ marker_begin }}'
    $end = '{{ marker_end }}'

    $content = Get-Content $path -Raw -ErrorAction SilentlyContinue
    if ($null -eq $content) { $content = "" }

    # Remove existing block
    $pattern = "(?s)\r?\n?" + [regex]::Escape($begin) + ".*?" + [regex]::Escape($end) + "\r?\n?"
    $content = [regex]::Replace($content, $pattern, "")
    $content = $content.TrimEnd()

    # Build new block
    $blockLines = @($begin)
    {% for entry in entries %}
    $blockLines += "{{ entry }}"
    {% endfor %}
    $blockLines += $end
    $block = $blockLines -join "`r`n"

    if ($content.Length -gt 0) {
      $newContent = $content + "`r`n" + $block + "`r`n"
    } else {
      $newContent = $block + "`r`n"
    }

    Set-Content -Path $path -Value $newContent -NoNewline -Encoding ASCII
  when: ansible_facts['os_family'] == "Windows"
```

### Module mapping

| Linux/macOS module | Windows equivalent | Notes |
|---|---|---|
| `ansible.builtin.blockinfile` | `ansible.windows.win_shell` + PowerShell | No native equivalent |
| `ansible.builtin.lineinfile` | `ansible.windows.win_lineinfile` | Available |
| `ansible.builtin.copy` | `ansible.windows.win_copy` | Available |
| `ansible.builtin.template` | `ansible.windows.win_template` | Available, uses `\r\n` line endings |
| `ansible.builtin.service` | `ansible.windows.win_service` | Available |
| `ansible.builtin.user` | `ansible.windows.win_user` | Available |
| `ansible.builtin.file` | `ansible.windows.win_file` | Available |

## Cross-Platform Role Patterns

When writing a role that targets multiple OS families, branch on `ansible_facts['os_family']`:

```yaml
# Linux + macOS — /etc/hosts
- name: "Manage hosts file (Linux/macOS)"
  ansible.builtin.blockinfile:
    path: /etc/hosts
    marker: "{mark}"
    marker_begin: "{{ marker_begin }}"
    marker_end: "{{ marker_end }}"
    block: |
      {% for domain in domains %}
      {{ sinkhole }} {{ domain }}
      {% endfor %}
    state: present
  become: true
  when: ansible_facts['os_family'] != "Windows"
  tags: ["hardening"]

# Windows — C:\Windows\System32\drivers\etc\hosts
- name: "Manage hosts file (Windows)"
  ansible.windows.win_shell: |
    # PowerShell script here
  when: ansible_facts['os_family'] == "Windows"
  tags: ["hardening"]
```

### OS family values

| OS | `ansible_facts['os_family']` |
|---|---|
| Debian, Ubuntu | `Debian` |
| Oracle Linux, RHEL, Rocky, Alma | `RedHat` |
| macOS | `Darwin` |
| Windows | `Windows` |

### macOS note

macOS uses `/etc/hosts` just like Linux — the same `blockinfile` task works for both. No separate macOS branch is needed for hosts file management.

## Windows Hosts File

The Windows hosts file is at `C:\Windows\System32\drivers\etc\hosts` — same path as Linux but with backslashes. The `win_shell` task runs as the Ansible user, which must have admin privileges to write to this path.

## Windows Roles in This Project

| Role | Purpose |
|---|---|
| `common-windows-ssh-hardening` | Harden OpenSSH server on Windows 10/11 |
| `common-windows-rdp-hardening` | Harden or disable RDP on Windows 10/11 |
| `common-hosts-blocklist` | Sinkhole privacy-violating domains (cross-platform) |

## Windows Playbook

| Playbook | Inventory | Host group |
|---|---|---|
| `harden-windows-host.yml` | `levonk/active/02-config/ansible/inventories/windows-docker.yml` | `windows_docker_hosts` |

Deploy with:

```bash
devbox run -- ansible-playbook \
  -i levonk/active/02-config/ansible/inventories/windows-docker.yml \
  shared/active/02-config/ansible/playbooks/harden-windows-host.yml \
  --vault-password-file ~/.ansible/vault_password
```
