# common-chromium-policy

Distributes Chromium-family enterprise policies that disable the built-in password manager, password leak/breach monitoring, and form autofill — so Bitwarden is the only credential manager.

## What it does

- **Disables the built-in password manager** (`PasswordManagerEnabled: false`) — no save prompts, no autofill, no suggested passwords
- **Disables breach/weak-password monitoring** (`PasswordLeakDetectionEnabled: false` on Chrome/Brave/Chromium, `PasswordMonitorAllowed: false` on Edge)
- **Disables form autofill** for addresses and credit cards (parity with `common-firefox-policy`)

Bitwarden extension autofill is unaffected — it injects via content scripts, not the browser's native credential manager.

## Why an Ansible role?

On macOS, enforced policies live in `/Library/Managed Preferences/<bundle-id>.plist` (root-owned, applied to all users — users cannot override them). On Linux, managed policy JSON lives under `/etc/opt/<browser>/policies/managed/`. On Windows, `HKLM\SOFTWARE\Policies` registry keys. All three require elevated privileges.

## Supported browsers

- Google Chrome
- Microsoft Edge
- Brave
- Chromium
- Arc
- Vivaldi
- Opera

Only browsers actually installed on the host receive a policy file (macOS/Linux). On Windows, registry keys are written unconditionally — uninstalled browsers ignore them.

## Platforms

- **Linux**: JSON into `/etc/opt/chrome/policies/managed/`, `/etc/opt/edge/policies/managed/`, `/etc/chromium/policies/managed/`, `/etc/opt/brave.com/brave/policies/managed/`
- **macOS**: plist into `/Library/Managed Preferences/<bundle-id>.plist`
- **Windows**: DWORDs under `HKLM\SOFTWARE\Policies\{Google\Chrome, Microsoft\Edge, Chromium, BraveSoftware\Brave}`

## Variables

| Variable | Default | Description |
|---|---|---|
| `chromium_policy_enabled` | `true` | Master switch — set `false` to skip entirely |
| `chromium_policy_macos_apps` | see defaults | bundle_id → .app path map |
| `chromium_policy_linux_dirs` | see defaults | managed policy directories |
| `chromium_policy_windows_keys` | see defaults | registry policy hives |
| `chromium_policy_values` | see defaults | policy name → value map |
