# common-firefox-policy

Distributes Firefox enterprise `policies.json` to system-level distribution directories (root/admin required).

## What it does

- **Force-installs Bitwarden** password manager extension on every Firefox-based browser
- **Disables the built-in password manager** (`OfferToSaveLogins: false`, `PasswordManagerEnabled: false`)
- **Disables telemetry** and Firefox studies
- **Disables form autofill** for addresses and credit cards
- **Forces popups to open as tabs** with full browser chrome (url bar, toolbar, bookmarks bar) so the Bitwarden extension is always accessible

## Why an Ansible role?

The system-level distribution directory (`/usr/lib/firefox/distribution/` on Linux, `Firefox.app/Contents/Resources/distribution/` on macOS, `C:\Program Files\Mozilla Firefox\distribution\` on Windows) requires root/admin privileges. The chezmoi dotfiles repo handles the user-level `user.js` profile sync; this role enforces the same settings at the enterprise level where users cannot override them.

## Supported browsers

- Firefox (regular, Developer Edition, Beta, Nightly, ESR)
- LibreWolf
- Waterfox
- Floorp
- Zen Browser
- Mullvad Browser

## Platforms

- **Linux**: Fixed paths + dynamic resolution from browser binary via `which` + `readlink -f`
- **macOS**: `.app` bundle paths under `/Applications/`
- **Windows**: `%PROGRAMFILES%` paths

The role is a no-op on browsers that are not installed (it checks if the parent directory exists before writing).

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `firefox_policy_enabled` | `true` | Enable/disable the role |
| `firefox_policy_source` | `policies.json` | Source file in `files/` |
| `firefox_policy_linux_dirs` | (see defaults) | Fixed Linux distribution dir candidates |
| `firefox_policy_linux_binaries` | (see defaults) | Linux binary names for dynamic resolution |
| `firefox_policy_macos_dirs` | (see defaults) | macOS `.app` bundle distribution dir candidates |
| `firefox_policy_windows_dirs` | (see defaults) | Windows `%PROGRAMFILES%` distribution dir candidates |
