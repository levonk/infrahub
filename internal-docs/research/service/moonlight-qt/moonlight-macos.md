# Moonlight (moonlight-qt) on macOS — Ansible Install & Config Research

Research for automating Moonlight (the Sunshine game-streaming client) on the
`macos_hosts` group (`lzkmbp2016` x86, `lzkmbp2018` x86, `lzkmm2026` arch TBD).
Ansible connects as `auser` (admin); the GUI/daily user is `micro`
(`macos_gui_user` inventory var). Precedent: `rustdesk-client` role
(`shared/active/02-config/ansible/roles/rustdesk-client/`).

TL;DR:
- `brew install --cask moonlight` — one universal DMG, same artifact for x86 and arm64.
- `/Applications/Moonlight.app` + a `moonlight` CLI symlink in the brew prefix bin dir.
- Only one privacy grant matters: **Local Network** (mDNS/LAN access, macOS 14/15+). Not a TCC grant — lives in `com.apple.networkextension.plist`. No Accessibility / Screen Recording / Input Monitoring / Microphone grants needed for a client.
- Pairing is per-user QSettings state (`~/Library/Preferences/com.moonlight-stream.Moonlight.plist`) — **pair as `micro`, not `auser`**.
- `moonlight pair --pin <NNNN> <host>` supports a pre-chosen PIN, and Sunshine's `/api/pin` REST endpoint is scriptable (Basic auth, no CSRF needed for non-browser clients) → pairing CAN be fully automated given Sunshine admin credentials.
- mDNS discovery does not cross Tailscale — add hosts by Tailscale FQDN/IP explicitly.

---

## 1. Install method

### Homebrew cask

- **Cask name: `moonlight`** (not `moonlight-qt`; no `moonlight` formula and no `moonlight-qt` cask exists).
- Current cask version: **6.2.0** (tracks GitHub release `v6.2.0`, released 2026-10-04).
- Source: `https://github.com/moonlight-stream/moonlight-qt/releases/download/v#{version}/Moonlight-#{version}.dmg`
- `depends_on macos: :ventura` → requires **macOS ≥ 13**. `LSMinimumSystemVersion` in the bundle is `13.0.0`.
- Not deprecated, not disabled.
- Sources:
  - https://formulae.brew.sh/cask/moonlight
  - https://raw.githubusercontent.com/Homebrew/homebrew-cask/HEAD/Casks/m/moonlight.rb
  - https://github.com/moonlight-stream/moonlight-qt/releases/latest

### What it installs

| Artifact | Path |
|---|---|
| App bundle | `/Applications/Moonlight.app` |
| Main binary | `/Applications/Moonlight.app/Contents/MacOS/Moonlight` |
| CLI symlink | `$(brew --prefix)/bin/moonlight` → the app binary (`binary` stanza in the cask) |
| Bundle ID | `com.moonlight-stream.Moonlight` |

The `moonlight` symlink lands in `/usr/local/bin` on Intel (x86) and
`/opt/homebrew/bin` on Apple Silicon (arm64) — same as the rustdesk role's
`macos_brew_dir` handling (`/opt/homebrew/bin` if `ansible_facts['architecture'] == 'arm64'` else `/usr/local/bin`).

### Arch differences

**None.** The cask downloads a single universal DMG — `Moonlight-6.2.0.dmg` has
identical sha256 for `arm:` and `intel:` in the cask definition, and the release
page lists one "macOS (Universal)" download. The release notes confirm the same
artifact serves both arches. So `lzkmm2026` needs no per-arch handling beyond the
usual brew-prefix path difference — whether it's arm64 or x86_64, the same cask
name, version, and sha256 apply. (For comparison, the Linux side of the cask is
x86_64-only AppImage — irrelevant here.)

Sources:
- https://raw.githubusercontent.com/Homebrew/homebrew-cask/HEAD/Casks/m/moonlight.rb (identical arm/intel sha256)
- https://github.com/moonlight-stream/moonlight-qt/releases/tag/v6.2.0 ("macOS (Universal)")

### Gatekeeper / quarantine

Homebrew downloads casks with curl, which does **not** set
`com.apple.quarantine`, so `brew install --cask moonlight` produces an app that
opens without a Gatekeeper "downloaded from the internet" dialog. No spctl/xattr
step is needed.

### v6.2.0 changes worth noting

- Default renderer on macOS is now **libplacebo (MoltenVK)** — selectable in Advanced Settings (`renderer` pref).
- Default streaming resolution for new installs is **1080p** (was 720p).
- AV1 hardware decode on macOS (M3+).
- `Metal` renderer now also works on discrete-GPU Macs.

Source: https://github.com/moonlight-stream/moonlight-qt/releases/tag/v6.2.0

---

## 2. Permissions / TCC

moonlight-qt is a **client** — it sends input out, it doesn't capture the local
screen or inject events. Inventory of what it does and doesn't need:

### Required-ish: Local Network privacy (macOS 14+, enforced hard on 15/Sequoia+)

- Moonlight's Info.plist declares:
  - `NSLocalNetworkUsageDescription` = "Moonlight uses the local network to connect to your gaming PC for streaming."
  - `NSBonjourServices` = `_nvstream._tcp` (the GameStream/Sunshine mDNS service type)
- On first launch macOS prompts: *"Moonlight would like to find and connect to devices on your local network."* → a human clicks **Allow**.
- **This is NOT a TCC grant.** Local Network privacy is enforced by nehelper and stored in `/Library/Preferences/com.apple.networkextension.plist` → `PathController.Rules` (NSKeyedArchiver blobs keyed by bundle ID). `tccutil reset` cannot touch it; the RustDesk role's sqlite-probe technique does **not** apply here.
  - Probe: `grep -a moonlight-stream /Library/Preferences/com.apple.networkextension.plist` (as root) detects whether the app ever prompted; reading the actual grant state out of the archiver blobs isn't practical.
  - Full reset requires deleting `com.apple.networkextension*.plist` from Recovery — don't go there.
- Grants pane: System Settings → Privacy & Security → **Local Network**.
  Anchor URL (same scheme the rustdesk role uses):
  `open 'x-apple.systempreferences:com.apple.preference.security?Privacy_LocalNetwork'`
- Known flakiness: on Sequoia there are reports of the toggle needing an off/on cycle after reboots (Moonlight issue #1450) and a Qt/Local-Network registration bug on macOS "Golden Gate" (issue #1910) — worth a smoke-test after first run.
- **Tailscale relevance:** Local Network privacy only gates traffic to *local* (LAN/link-local) destinations. Connections routed through Tailscale's `utun` interface to `100.64.0.0/10` addresses are not LAN traffic, so pairing/streaming to the Sunshine host over Tailscale should work even without this grant. Grant it anyway: Moonlight runs an mDNS browse at startup on the LAN interface, and any LAN-resident Sunshine host would silently fail without it. (No hard source for the utun exemption — flag for testing on the first Mac.)
- If LAN access without prompting is ever needed fleet-wide, TN3179 documents a system-wide opt-out via `sudo defaults write com.apple.network.local-network Allowed{Ethernet,WiFi}LocalNetworkAddresses -array "<cidr>"` — requires reboot; likely overkill here.

Sources:
- https://raw.githubusercontent.com/moonlight-stream/moonlight-qt/master/app/Info.plist
- https://github.com/moonlight-stream/moonlight-qt/issues/1450 (Sequoia Local Network toggle workaround + `tccutil` failure)
- https://github.com/moonlight-stream/moonlight-qt/issues/1910 (macOS 27/QNetworkAccessManager Local Network bug)
- https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy.md
- https://zachbr.io/posts/2025-11-29-reset-macos-local-network-permissions/ (plist location, System Settings toggle ↔ file write)

### NOT needed (verified against Info.plist + feature list)

| Grant | Needed? | Why |
|---|---|---|
| Accessibility | No | Client sends input to the host; nothing captures local input |
| Input Monitoring | No | Keyboard/mouse/gamepad capture uses normal event delivery + SDL hints; gamepads via IOKit HID don't need it |
| Screen Recording | No | It's a *decoder*/display, not a capturer |
| Microphone | No | Stock moonlight-qt has **no mic passthrough** (UDP 48002 is reserved-but-unused upstream; mic passthrough exists only in forks like Apollo + moonlight-qt-mic). No `NSMicrophoneUsageDescription` in Info.plist |
| Camera | No | — |
| Full Disk Access | No | — |

Sources:
- https://raw.githubusercontent.com/moonlight-stream/moonlight-qt/master/app/Info.plist (no mic/camera/accessibility usage keys)
- https://github.com/moonlight-stream/moonlight-qt — feature list (no mic passthrough)
- https://github.com/LizardByte/Sunshine/pull/833 (UDP 48002 reserved/unused)
- https://github.com/logabell/moonlight-qt-mic (fork that adds it)

### Possible first-launch prompt: Application Firewall

If the macOS Application Firewall is enabled on a host, the OS may ask *"Do you
want the application 'Moonlight.app' to accept incoming network connections?"*
because Moonlight binds UDP ports for the incoming video/audio/control streams.
Signed/notarized apps are auto-allowed when "Automatically allow built-in
software / signed software" is on; if the fleet's firewall config is stricter
this becomes a second human click. Check `socketfilterfw` state on the target
Macs before assuming.

### Human clicks on first launch — summary

1. (macOS 15+) **Allow Local Network** prompt — one click, on first `open -a`.
2. Possibly the firewall incoming-connections prompt (if ALF is on and strict).
3. Pairing PIN entry (see §3) — inherent to the protocol.
4. That's it — no privacy-pane handoff comparable to RustDesk's three toggles.

---

## 3. Pairing flow

### How pairing works (protocol)

1. Moonlight discovers Sunshine hosts two ways:
   - **mDNS** — browses for `_nvstream._tcp` (Bonjour, UDP 5353). LAN-only.
   - **Manual add** — "Add PC" in the GUI, or a host argument to the CLI. Accepts hostname/FQDN, IPv4, IPv6 (URL-escaped), and optional `:port` (default 47989, the GameStream HTTP port). Implementation: `addNewHostManually()` parses `moonlight://<address>` URLs — any DNS-resolvable name works, including `*.tale-grouper.ts.net` FQDNs.
2. Client generates a 4-digit PIN and sends a pair request (HTTPS :47984 on the host).
3. **Human step:** that PIN must be entered on the host side —
   - Sunshine: web UI `https://<host>:47990` → "PIN" page (prompt said 47984 — the correct web-UI port is **47990**; 47984 is the HTTPS GameStream port Moonlight itself talks to).
   - Host PIN entry is not optional; it's the auth ceremony.
4. On success, Sunshine returns `pair-status=1` and the host appears paired in Moonlight's PC list.

Sources:
- https://github.com/moonlight-stream/moonlight-docs/wiki/Setup-Guide
- https://raw.githubusercontent.com/moonlight-stream/moonlight-qt/master/app/backend/computermanager.cpp (`addNewHostManually`, DEFAULT_HTTP_PORT 47989)
- https://docs.lizardbyte.dev/projects/sunshine/v0.18.4/about/usage.html (web UI :47990, PIN navbar)
- https://github.com/moonlight-stream/moonlight-qt/issues/826 ("47989 is for pairing; 47990 is the admin GUI")

### CLI interface

The cask exposes `moonlight` → `Moonlight.app/Contents/MacOS/Moonlight`. Running it
with a subcommand enters CLI mode (defined in `app/cli/commandlineparser.cpp`):

| Command | Args | Notes |
|---|---|---|
| `moonlight pair <host> [--pin NNNN]` | host = name / UUID / IP / FQDN | **Shows a GUI window** (`CliPair.qml`) displaying "Pairing... Please enter 'NNNN' on <pc>." `--pin` pre-chooses the 4-digit PIN instead of generating a random one. On success shows a "Pairing completed successfully" dialog — needs a click or Esc to close; process exits then. 10 s host-seek timeout. |
| `moonlight list <host> [--csv] [--verbose]` | — | **No window** (`hasGUI = false`) — prints app list to stdout (paired hosts only). Still constructs a `QGuiApplication`, so run it as a user that owns a GUI session (e.g. `micro` via `become_user`), not as a session-less SSH user — the macOS WindowServer rejects GUI-app init otherwise. |
| `moonlight stream <host> "<app>" [opts]` | app = e.g. `"Desktop"`, `"Steam"` | Starts a session with optional overrides. Flags: `--720/--1080/--1440/--4K`, `--resolution WxH`, `--fps N` (10–480), `--bitrate Kbps` (500–500000), `--packet-size`, `--display-mode fullscreen\|windowed\|borderless`, `--audio-config stereo\|5.1-surround\|7.1-surround`, `--video-codec auto\|H.264\|HEVC\|AV1`, `--video-decoder auto\|hardware\|software`, `--capture-system-keys never\|fullscreen\|always`, plus toggle pairs `--x`/`--no-x` for vsync, multi-controller, quit-after, absolute-mouse, frame-pacing, hdr, yuv444, keep-awake, performance-overlay, etc. |
| `moonlight quit <host>` | — | Quits the running app on the host. Also GUI-ish (loads `CliQuitStreamSegue.qml`). |
| (no `unpair`) | — | Unpair via GUI, or host-side `POST /api/unpair` / `/api/clients/unpair-all`. |

Source: https://raw.githubusercontent.com/moonlight-stream/moonlight-qt/master/app/cli/commandlineparser.cpp

### GUI-session requirement (important for Ansible)

- All subcommands construct a `QGuiApplication`; `pair`/`stream`/`quit` load QML views → **they need a window server**. `list` is the exception.
- Pairing state is **per-user** (per-user QSettings, see §4). Running `moonlight pair` as `auser` over SSH writes `auser`'s plist, not `micro`'s — and likely has no GUI session to render into anyway.
- Correct pattern: run the pair/stream commands as the console GUI user — either
  `become_user: micro` (works when `micro` owns the console session; the app
  displays on the console) or `open -a Moonlight --args pair --pin <pin> <host>`
  (LaunchServices delivers to the active GUI session; `open` returns immediately).
- The pair window is tiny but visible — a human at the console will see "enter PIN NNNN". With `--pin`, Ansible picks the PIN, so the window is informational rather than required reading.

### Fully-automated pairing via the Sunshine REST API

The PIN handoff does **not** have to be a human in the web UI. Sunshine's config
HTTP server (`https://<host>:47990`, HTTP Basic auth = Sunshine admin creds)
exposes `/api/pin`:

**Sunshine ≤ v2026.516.x** (old shape, still seen on most deployed versions):
```
POST /api/pin   {"pin": "1234", "name": "Friendly Client Name"}
→ {"status": true}
```

**Sunshine ≥ ~v2026.906.x** (current; pending-pairing model):
```
GET    /api/pin                         → {"pairings": [{"id": "<32-hex>", "name": "...", "address": "..."}]}
POST   /api/pin {"pairing_id": "<id>", "pin": "1234", "name": "..."}  → {"status": true|false}
DELETE /api/pin {"pairing_id": "<id>"}  # cancel
```
The POST stays open while the cryptographic handshake completes; wrong PIN /
timeout → `{"status": false}`.

**CSRF:** requests must authenticate (Basic auth). CSRF tokens
(`GET /api/csrf-token` → `X-CSRF-Token` header) are only enforced for
browser-like requests carrying `Origin`/`Referer` headers — non-browser clients
(curl, Ansible `uri`) are explicitly exempt.

So a fully hands-off pairing recipe is:

```
# on the Mac, as micro (GUI session):
open -a Moonlight --args pair --pin 4521 <sunshine-tailscale-fqdn>
# from anywhere with HTTPS reach to the Sunshine web UI (control machine):
curl -k -u admin:<sunshine-pass> https://<host>:47990/api/pin         # find pairing_id (new API)
curl -k -u admin:<sunshine-pass> -H 'Content-Type: application/json' \
     -d '{"pairing_id":"<id>","pin":"4521","name":"lzkmbp2016"}' \
     https://<host>:47990/api/pin                                    # {"status":true}
```

Old-API hosts skip the GET and post `{"pin":"4521","name":"lzkmbp2016"}` directly.
Prerequisites: Sunshine admin credentials (vault), and the client must already
have sent its pair request (the `moonlight pair` window must be actively
pairing — kick the API call within Sunshine's pending-pairing window).

Sources:
- https://raw.githubusercontent.com/LizardByte/Sunshine/master/src/confighttp.cpp (`getPendingPairings`, `savePin`, `cancelPairing`, `validate_csrf_token` exemption for requests without Origin/Referer)
- https://raw.githubusercontent.com/LizardByte/Sunshine/v2025.122.141614/src/confighttp.cpp (old `{"pin","name"}`-only shape)
- API-shape change verified between tags `v2026.516.143833` (old) and `v2026.906.222525` (new); latest release `v2026.914.233613` uses the new shape.

### Where pairing state lives

- All in the per-user QSettings domain `com.moonlight-stream.Moonlight` (see §4):
  - `uniqueid` — generated client UID
  - `certificate` / `key` — self-signed RSA-2048 client cert + private key (PEM blobs; generated on first run)
  - `hosts` / `hostsbackup` — array of paired `NvComputer` records including each host's server cert
- Pairing is therefore per-(macOS-user)-per-machine: `micro`'s pairing doesn't help `auser`, and the same client identity doesn't roam.
- Wiping the plist (or `brew uninstall --zap moonlight`) unpairs everything.

Source: https://raw.githubusercontent.com/moonlight-stream/moonlight-qt/master/app/backend/identitymanager.cpp

---

## 4. Config file

### Location & format

- `QCoreApplication::setOrganizationName("Moonlight Game Streaming Project")` + `setApplicationName("Moonlight")`, default `QSettings` → **NativeFormat on macOS → `~/Library/Preferences/com.moonlight-stream.Moonlight.plist`** (per-user).
- Flat key space (no settings group in current code).
- Other paths (from the cask's `zap` stanza):
  - `~/Library/Caches/Moonlight Game Streaming Project/` (boxart, qmlcache)
  - `~/Library/Saved Application State/com.moonlight-stream.Moonlight.savedState`
  - Logs: `/tmp` on macOS (`Path::initialize` — deliberately not `$TMPDIR`)
- On Linux it's `~/.config/Moonlight Game Streaming Project/Moonlight.conf` — NOT on macOS.

Sources:
- https://raw.githubusercontent.com/moonlight-stream/moonlight-qt/master/app/main.cpp (org/app names)
- https://raw.githubusercontent.com/moonlight-stream/moonlight-qt/master/app/path.cpp
- https://raw.githubusercontent.com/Homebrew/homebrew-cask/HEAD/Casks/m/moonlight.rb (zap paths)

### Writable via `defaults write`?

Yes — it's a standard CFPreferences domain:

```bash
# as micro, Moonlight closed:
defaults write com.moonlight-stream.Moonlight width -int 1920
defaults write com.moonlight-stream.Moonlight height -int 1080
defaults write com.moonlight-stream.Moonlight fps -int 60
defaults write com.moonlight-stream.Moonlight bitrate -int 20000
defaults write com.moonlight-stream.Moonlight windowmode -int 1
defaults write com.moonlight-stream.Moonlight mdns -bool true
defaults write com.moonlight-stream.Moonlight capturesyskeys -int 1
```

Caveats:
- Run as the **target user** (`micro`), while Moonlight is **not running** — the
  app reads prefs once at startup and `save()` overwrites the whole set on exit /
  settings change. `killall cfprefsd` after writing is belt-and-braces.
- Ansible: `community.general.osx_defaults` (or `command: defaults write ...` with
  `become_user: micro`). This isn't templating a file — there's no .ini/.conf to
  drop. A `defaults read` + diff loop is the idempotency story, or accept
  `changed` every run (osx_defaults handles idempotency natively).

### Key reference (`SER_*` in `streamingpreferences.cpp`)

| Plist key | Type | Default | Meaning |
|---|---|---|---|
| `width` / `height` | int | 1920 / 1080 | Stream resolution (v6.2 default 1080p) |
| `fps` | int | 60 | Frame rate |
| `bitrate` | int | computed | Kbps; default = `round(resFactor*fpsFactor)*1000` — 1080p60 ≈ 20 Mbps, 1440p60 ≈ 40 Mbps, 4K60 ≈ 80 Mbps |
| `autoadjustbitrate` | bool | true | Auto-adjust bitrate w/ res/fps changes |
| `unlockbitrate` | bool | false | Allow >80 Mbps in UI |
| `windowmode` | int | 1 on macOS | 0=fullscreen, 1=borderless(WM_FULLSCREEN_DESKTOP — recommended on Darwin), 2=windowed |
| `uidisplaymode` | int | 0 | 0=windowed,1=maximized,2=fullscreen (the Moonlight UI itself) |
| `audiocfg` | int | 0 | 0=stereo, 1=5.1, 2=7.1 |
| `videocfg` | int | 0 | 0=auto, 1=H.264, 2=HEVC, 4=AV1 (3=deprecated HEVC_HDR — don't use) |
| `videodec` | int | 0 | 0=auto, 1=hardware, 2=software |
| `renderer` | int | 0 | macOS only: 0=auto, 1=Vulkan(libplacebo/MoltenVK — v6.2 default), 2=Metal, 3=AVSampleBufferDisplayLayer |
| `hdr` | bool | false | HDR streaming |
| `yuv444` | bool | false | YUV 4:4:4 (Sunshine only; doubles bitrate factor) |
| `mdns` | bool | true | mDNS host discovery — keep on; harmless over Tailscale since manual add always works |
| `vsync` | bool | true | — |
| `framepacing` | bool | false | — |
| `gameopts` | bool | true | "Game optimizations" (host-side tweaks) |
| `hostaudio` | bool | false | Play audio on host too |
| `multicontroller` | bool | true | Multi-gamepad support |
| `gamepadmouse` | bool | true | Gamepad-as-mouse in UI |
| `backgroundgamepad` | bool | false | Gamepad input while unfocused |
| `quitAppAfter` | bool | false | Quit app on host after session |
| `mouseacceleration` | bool | false | Absolute mouse (remote-desktop mode) |
| `swapmousebuttons` | bool | false | — |
| `abstouchmode` | bool | true | Touchscreen = absolute (vs trackpad) |
| `reversescroll` | bool | false | Invert scroll |
| `swapfacebuttons` | bool | false | Nintendo-style A/B,X/Y swap |
| `capturesyskeys` | int | 0 | 0=never, 1=fullscreen-only, 2=always — system-key capture (Cmd+Tab etc.) via SDL keyboard grab; no TCC grant needed |
| `keepawake` | bool | true | Prevent display sleep while streaming |
| `muteonfocusloss` | bool | false | — |
| `showperfoverlay` | bool | false | Stats overlay |
| `packetsize` | int | 0 | 0=auto(1392), else bytes (>1024) — consider ~1400-28 or smaller if Tailscale MTU is an issue |
| `connwarnings` / `confwarnings` | bool | true | Pre-launch warnings |
| `detectnetblocking` | bool | true | Firewall-blocking detection |
| `richpresence` | bool | true | Discord presence |
| `language` | int | 0 | 0=auto |
| `defaultver` | int | — | Internal default-migration marker (=2) |

### Pairing-state keys (same plist — don't template these)

`uniqueid`, `certificate`, `key`, `hosts`, `hostsbackup`. A `defaults write`
that clobbers `hosts` would unpair — the Ansible task should set only the
explicit pref keys it manages.

Sources:
- https://raw.githubusercontent.com/moonlight-stream/moonlight-qt/master/app/settings/streamingpreferences.cpp
- https://raw.githubusercontent.com/moonlight-stream/moonlight-qt/master/app/settings/streamingpreferences.h
- https://raw.githubusercontent.com/moonlight-stream/moonlight-qt/master/app/backend/identitymanager.cpp
- https://raw.githubusercontent.com/moonlight-stream/moonlight-qt/master/app/backend/computermanager.cpp

---

## 5. Network reachability (client → Sunshine host)

### Port matrix (Sunshine defaults; base port 47989 is configurable and offsets everything)

| Proto | Port(s) | Purpose |
|---|---|---|
| TCP | **47984** | HTTPS GameStream API (serverinfo, pairing, app launch) |
| TCP | **47989** | HTTP GameStream API (manual-add default port, port test) |
| TCP | 47990 | Sunshine **web UI** (admin + PIN page) — needed only for the human/API pairing step |
| TCP | **48010** | RTSP stream setup |
| UDP | **47998** | Video stream (host → client) |
| UDP | **47999** | Control stream |
| UDP | **48000** | Audio stream (host → client) |
| UDP | 48002 | Mic passthrough — reserved, unused by stock moonlight-qt |
| UDP | **48010** | RTSP over UDP fallback |
| UDP | 5353 | mDNS host discovery — **LAN multicast only; does not cross Tailscale** |

Sunshine firewall docs expose `47984–47990/tcp` + `48010/tcp` + `47998–48000/udp`
as the required inbound set on the host side.

Sources:
- https://github.com/moonlight-stream/moonlight-docs/wiki/Setup-Guide (manual-forwarding port list)
- https://docs.lizardbyte.dev/projects/sunshine/latest/md_DOCKER__README.html (required port mappings)
- https://www.mintlify.com/LizardByte/Sunshine/deployment/security (base-port offset model: web UI = base+21 → 48010 in their table; note the actual admin UI has historically been on 47990 — the canonical doc `usage.html` says 47990)

### Tailscale considerations

- **mDNS won't cross Tailscale** — no multicast over WireGuard. Auto-discovery
  will never find the host via the tailnet; hosts must be added explicitly.
- Manual add accepts FQDNs → `lzkmm2026 → moonlight pair kckinai.tale-grouper.ts.net` works; MagicDNS resolves the name and traffic flows over WireGuard. Raw `100.x` IPs work too.
- Ensure the Sunshine host is reachable on the Tailscale IPs for TCP 47984/47989/48010 (+47990 for web-UI pairing) and UDP 47998–48000/48010 — i.e., the host's Tailscale ACLs and local firewall must allow the tailnet.
- **MTU:** Tailscale links are ~1280 MTU. Moonlight's default video packet size is 1392 bytes; fragmented UDP video over WireGuard is a classic jank source. Consider templating `packetsize` ≈ 1200–1280 or relying on `--packet-size` per-stream, and verify — worth a real-world test before fleet defaults.
- **Local Network privacy (macOS 15+)** only applies to LAN traffic — Tailscale-routed connections shouldn't need the grant (unverified on utun; test on first host).
- The client also *binds* UDP ports for inbound streams → see the Application Firewall note in §2.

### First-connect check the app does

Moonlight runs a port test against the host on TCP 47984/47989 when adding it
(`ML_PORT_FLAG_TCP_47984 | ML_PORT_FLAG_TCP_47989` in computermanager.cpp) —
"Failed to connect to <host>" from `moonlight pair` almost always means those
two TCPs aren't reachable.

---

## 6. Ansible integration sketch

Modeled on `roles/rustdesk-client/tasks/darwin.yml`. Proposed role `moonlight-client`:

```yaml
# defaults/main.yml (sketch)
moonlight_client_enabled: true
moonlight_client_macos_app_path: "/Applications/Moonlight.app"
moonlight_client_macos_app_bin: "{{ moonlight_client_macos_app_path }}/Contents/MacOS/Moonlight"
moonlight_client_macos_gui_user: "{{ macos_gui_user | default('') }}"   # resolves to micro
moonlight_client_prefs:                # written via osx_defaults as the GUI user
  width: 1920
  height: 1080
  fps: 60
  # bitrate: 20000                   # omit → app computes default
  windowmode: 1                      # borderless (recommended on macOS)
  mdns: true
  capturesyskeys: 1                  # capture Cmd+Tab in fullscreen
moonlight_client_sunshine_host: ""     # e.g. kckinai.tale-grouper.ts.net — pair target
moonlight_client_pair: false           # run the semi-automated pair flow
moonlight_client_pair_pin: ""          # 4-digit PIN; generated if empty
```

Task flow (`tasks/darwin.yml`):

1. Resolve console GUI user (copy the rustdesk role's `stat -f%Su /dev/console` + `macos_gui_user` fallback block — same three-task stanza).
2. `ansible.builtin.stat` the app bin → `community.general.homebrew_cask: name: moonlight state: present path: "{{ macos_brew_dir | default(...) }}" install_options: "appdir=/Applications"` → assert. (Identical to rustdesk.)
3. *(optional)* `community.general.osx_defaults` loop over `moonlight_client_prefs` in domain `com.moonlight-stream.Moonlight`, `become_user: <gui user>`, while app is closed.
4. First launch: `open -a /Applications/Moonlight.app` as the GUI user — registers the Local Network prompt. Handoff message: "click **Allow** on the Local Network prompt; toggle is under Privacy & Security → Local Network". Optionally `open` the pane anchor `Privacy_LocalNetwork`.
   - Unlike RustDesk there is **no reliable db probe** for the grant (it's in `com.apple.networkextension.plist` archiver blobs) — just grep the file for `moonlight-stream` to detect "prompted at least once", or keep a `moonlight_client_macos_permissions_granted: true` inventory flag like rustdesk's.
5. Pairing (when `moonlight_client_pair` and `moonlight_client_sunshine_host` set):
   - Generate a PIN (`"%04d" | format(9999 | random)`), `open -a Moonlight --args pair --pin <pin> <host>` as the GUI user (or `become_user: micro` + direct binary call).
   - Then `ansible.builtin.uri` POST to Sunshine `/api/pin` (see §3) using vault'd Sunshine admin creds + `validate_certs: false` — fully automated; or fall back to printing the PIN for a human to enter at `https://<host>:47990` if creds aren't managed.
   - Verify with `moonlight list <host>` **as micro** (non-GUI, safe for SSH) — a successful app list = paired + reachable.
6. Report task mirroring rustdesk's status block: app version, paired state, remaining manual steps.

### What cannot be automated

| Step | Automatable? |
|---|---|
| Cask install | ✅ `community.general.homebrew_cask` |
| Preferences | ✅ `osx_defaults` as the GUI user |
| First-launch Local Network **Allow** click | ❌ Human (or MDM). Pane-opening automatable; the toggle is not |
| Pairing PIN | ⚠️ Fully automatable **if** Sunshine admin creds are available (API path above). Otherwise the human enters the PIN at `https://<host>:47990`. With `--pin` the PIN is role-controlled, so the handoff is a stable instruction |
| Pairing window dismiss ("completed successfully" dialog) | ⚠️ The dialog needs a click/Esc, or Ansible can `pkill -f "Moonlight pair"` after confirming `moonlight list` succeeds |
| Streaming launch | ✅ `moonlight stream <host> "<app>"` as micro — or just let the human click |

### Idempotency notes

- `homebrew_cask` is idempotent; the stat/assert pattern from rustdesk adds a friendly failure when brew is missing.
- `osx_defaults` is idempotent per key/value.
- Pairing: probe `defaults read com.moonlight-stream.Moonlight hosts` (as micro) — non-empty array = already paired, skip pair flow. `moonlight list <host>` doubles as a reachability check.
- Multi-user caveat: pairing written by `auser`'s run is invisible to `micro`. All Moonlight tasks that touch prefs or run the binary should `become_user:` the resolved GUI user.

---

## 7. Host-by-host notes

| Host | Arch | Notes |
|---|---|---|
| lzkmbp2016 | x86_64 (macOS 15.7.7) | Same cask/artifact. Brew prefix `/usr/local` → `moonlight` at `/usr/local/bin/moonlight`. Also the Ansible control machine. |
| lzkmbp2018 | x86_64 | Same as above. Remote via Tailscale SSH. |
| lzkmm2026 | TBD — likely arm64 ("mm" = Mac mini / Apple Silicon?) | **Arch handling is a non-issue for the cask itself** (universal DMG, one sha256). The only arch-dependent path is the brew symlink: `/opt/homebrew/bin/moonlight` on arm64. Reuse `macos_brew_dir`/`ansible_facts['architecture']` like rustdesk does — don't hardcode either prefix. If it turns out to be Intel, nothing else changes. |

macOS floor is 13 (Ventura) per both the cask's `depends_on` and `LSMinimumSystemVersion` — all three hosts are well above it.

---

## 8. Source index

- Cask: https://formulae.brew.sh/cask/moonlight · https://raw.githubusercontent.com/Homebrew/homebrew-cask/HEAD/Casks/m/moonlight.rb
- Releases: https://github.com/moonlight-stream/moonlight-qt/releases/tag/v6.2.0 · repo https://github.com/moonlight-stream/moonlight-qt
- moonlight-qt source (master):
  - `app/Info.plist` — bundle id, NSLocalNetworkUsageDescription, NSBonjourServices, LSMinimumSystemVersion
  - `app/cli/commandlineparser.cpp` — `list|quit|stream|pair` subcommands + all stream flags
  - `app/cli/pair.cpp`, `app/gui/CliPair.qml` — GUI pair window, `--pin` predefined-PIN path
  - `app/main.cpp` — QSettings org/app names, per-subcommand GUI flags
  - `app/backend/computermanager.cpp` — manual-add URL parsing, `hosts`/`hostsbackup` QSettings arrays, TCP 47984/47989 port test
  - `app/backend/computerseeker.cpp` — host resolution by name/UUID/address
  - `app/backend/identitymanager.cpp` — `uniqueid`/`certificate`/`key` in QSettings
  - `app/settings/streamingpreferences.{h,cpp}` — all pref keys, enums, defaults, bitrate table
  - `app/path.cpp` — `/tmp` log dir, cache dirs
- Docs: https://github.com/moonlight-stream/moonlight-docs/wiki/Setup-Guide (pairing steps, port list)
- Sunshine: https://docs.lizardbyte.dev/projects/sunshine/latest/md_DOCKER__README.html · https://docs.lizardbyte.dev/projects/sunshine/v0.18.4/about/usage.html (web UI :47990) · `src/confighttp.cpp` at master + v2025.122.141614 + v2026.516.143833 + v2026.906.222525 (the `/api/pin` shapes and CSRF-exemption)
- Local Network privacy: https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy.md · https://github.com/moonlight-stream/moonlight-qt/issues/1450 · https://github.com/moonlight-stream/moonlight-qt/issues/1910 · https://zachbr.io/posts/2025-11-29-reset-macos-local-network-permissions/
- Mic passthrough non-status: https://github.com/LizardByte/Sunshine/pull/833 · https://github.com/logabell/moonlight-qt-mic
