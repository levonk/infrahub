# Sunshine (Moonlight host) in Docker on Windows 11 / Docker Desktop (WSL2)

Research for the infrahub Ansible role targeting **dtop202311**
(Windows 11 + Docker Desktop, Linux containers / WSL2 backend, x86_64, reached via Tailscale + SSH).

Companion file: `ports-and-config.md` (exact port table, volumes, env vars, sample Ansible/docker config).

---

## 1. Feasibility reality-check

### A Linux container cannot see or capture the Windows desktop — confirmed

Sunshine's screen-capture backends are documented in the feature matrix and `capture`
config option. On Linux they are: KMS/DRM, NvFBC (X11 only), wlroots/Wayland screencopy,
X11 (XCB), XDG Desktop Portal, and KWin screencast. DXGI Desktop Duplication (`ddx`) and
Windows.Graphics.Capture (`wgc`) — the methods that capture the actual Windows desktop —
are **Windows-only**.

- Source: <https://docs.lizardbyte.dev/projects/sunshine/latest/> (Feature Compatibility tables)
- Source: <https://github.com/LizardByte/Sunshine/blob/master/docs/configuration.md> (`capture` option; `ddx`/`wgc` marked "Applies to Windows only")

A Linux container under Docker Desktop shares the WSL2 VM's kernel and sees only
virtualized devices (`/dev/dxg`, `/dev/dri/*` via GPU paravirtualization). There is no
path from inside the container to the Windows display driver stack, so **no container
config will ever stream the Windows desktop**. If that is the goal, install Sunshine
natively (§5).

### What works: a self-contained virtual desktop inside containers ("games-on-whales" pattern)

The established pattern is to run a *virtual* display server (Xorg with a dummy driver,
or a headless Wayland compositor) plus PulseAudio *inside* Docker, and have a streamer
capture/encode that virtual session. The games-on-whales project implements this two ways:

- **Legacy stack (stale):** separate `xorg` + `pulseaudio` + `sunshine` containers sharing
  the X11 socket. Compose file:
  <https://github.com/games-on-whales/gow/blob/2e442292d79b9d996f886b8a03d22b6eb6bddf7b/compose/streamers/sunshine.yml>
  The corresponding images (`ghcr.io/games-on-whales/sunshine:edge`, `xorg`, `pulseaudio`)
  were last published **over a year ago** and the `images/` tree no longer contains them —
  the repo was restructured around Wolf.
  Sources: <https://github.com/games-on-whales/gow/pkgs/container/sunshine>,
  <https://github.com/games-on-whales/gow/tree/master/images>
- **Current stack (maintained):** **Wolf** (`ghcr.io/games-on-whales/wolf:stable`) — a
  Moonlight-protocol streaming server that spins up app/desktop containers on demand using
  a custom headless Wayland compositor (gst-wayland-display) feeding a GStreamer pipeline.
  It speaks the Moonlight protocol directly (it is *not* Sunshine, but serves the same
  purpose and clients).
  Sources: <https://github.com/games-on-whales/wolf/>, <https://games-on-whales.github.io/wolf/stable/index.html>,
  <https://games-on-whales.github.io/wolf/stable/dev/how-it-works.html>

### GPU-accelerated encoding under WSL2 — better than expected, but with caveats

The naive assumption "no hardware encode in WSL2" is **out of date**:

1. **VA-API via D3D12 (vendor-agnostic, officially supported by Microsoft/WSLg).**
   WSLg exposes the paravirtualized GPU through Mesa's `d3d12` Gallium driver, which
   implements VA-API on top of Direct3D 12 — including **H.264 and HEVC encode**
   (`VAEntrypointEncSlice`), on Intel, AMD, and NVIDIA Windows drivers alike.
   Microsoft ships an official container sample showing exactly what a container needs:
   devices `/dev/dxg`, `/dev/dri/card0`, `/dev/dri/renderD128`; mount `/usr/lib/wsl`;
   env `LIBVA_DRIVER_NAME=d3d12` and `LD_LIBRARY_PATH=/usr/lib/wsl/lib`; and
   `mesa-va-drivers` + `vainfo` in the image.
   - <https://devblogs.microsoft.com/commandline/d3d12-gpu-video-acceleration-in-the-windows-subsystem-for-linux-now-available/>
   - <https://github.com/microsoft/wslg/commit/57a717d4633ce59858458935f64130801ac1747f>
   - <https://www.phoronix.com/news/HEVC-VA-API-To-D3D12-Mesa> (HEVC encode merged Mesa 22.3)
   Sunshine supports `encoder = vaapi` on Linux, so this path is plausible — but
   upstream does not test Sunshine under WSL2, so treat it as unverified.

2. **NVENC under WSL2 (NVIDIA only).** NVIDIA's FFmpeg-with-GPU docs now list WSL as a
   supported OS (Turing or newer), and the DeepStream-on-WSL FAQ documents bind-mounting
   `libnvidia-encode.so.1` / `libnvcuvid.so.1` from `/usr/lib/wsl/lib` into the container.
   NVIDIA's CUDA-on-WSL "Features Not Yet Supported" list no longer names NVENC/NVDEC.
   On Docker Desktop specifically, use Compose/`docker run --gpus all` (GPU-PV) — **not**
   `runtime: nvidia`, which mounts only the management library and fails at encode time
   with a misleading driver error.
   - <https://docs.nvidia.com/video-technologies/video-codec-sdk/13.1/ffmpeg-with-nvidia-gpu/index.html>
   - <https://docs.nvidia.com/metropolis/deepstream/dev-guide/text/DS_WSL2_FAQ.html>
   - <https://docs.nvidia.com/cuda/wsl-user-guide/> (§5.2)
   - <https://docs.docker.com/desktop/features/gpu>
   - <https://lumastra.org/guides/gpu-transcoding/> (Docker Desktop `runtime: nvidia` pitfall)

3. **Software x264 fallback always works** (`encoder = software`). Budget several CPU
   cores for 1080p60; 4K software encode is generally impractical. Sunshine's own docs
   warn HEVC/AV1 software encoding is much more CPU-intensive than H.264
   (`hevc_mode`, `av1_mode` notes in configuration.md).

4. **What does NOT work under WSL2:** real KMS/DRM capture. `/dev/dri/card0` exists via
   GPU-PV, but the paravirtual GPU has no real scanout — a community test of the GOW
   stack on WSL2 logged `Couldn't expose some/all drm planes for card: /dev/dri/card0`,
   Sunshine started and served the web UI, but Moonlight could not connect.
   So capture inside the container must be X11 (Xorg/Xvfb socket) or headless Wayland —
   exactly what Wolf and the GOW stack provide.
   - <https://github.com/games-on-whales/gow/issues/13>

### Input devices caveat (uinput)

Sunshine on Linux needs `/dev/uinput` (and `/dev/input/uinput`) to create virtual
keyboard/mouse/gamepads. The stock WSL2 kernel has historically **lacked the uinput
module**, and WSL2 can't load out-of-tree modules — a custom kernel build was the
workaround. Wolf explicitly documents a degraded WSL2 mode: without `uinput`/`uhid` you
are "restricted to only using mouse and keyboard" (no gamepads), and states
"Running Wolf in WSL2 hasn't been properly tested."
- <https://docs.lizardbyte.dev/projects/sunshine/latest/md_docs_2configuration.html> ("Permissions on every platform")
- <https://games-on-whales.github.io/wolf/stable/user/quickstart.html> (WSL2 tab)
- <https://github.com/games-on-whales/gow/issues/13> (uinput missing in WSL2 kernel)

**Action item for the role:** probe `test -e /dev/uinput` inside the WSL2 VM /
`docker run --rm alpine ls /dev/uinput` before promising gamepad support.

### Host networking caveat

Wolf expects `--network=host`. Docker Desktop supports host networking only since
**v4.34**, as an opt-in (Settings → Resources → Network → "Enable host networking"),
and it is layer-4 only (TCP/UDP OK — fine for Moonlight — but the container binds the
VM's network, not Windows interfaces directly).
- <https://docs.docker.com/engine/network/drivers/host/> (Docker Desktop section)

### mDNS / auto-discovery caveat

Sunshine advertises via mDNS (UDP 5353); under Docker Desktop's NAT'd networking the
advertisement will not be useful on the LAN or tailnet. Moonlight's **"Add Host
Manually"** with `<host-ip>:47989` (HTTP base port) is the reliable path — including
over Tailscale, where the Tailscale IP works fine with manual add.
- <https://nixos.wiki/wiki/Sunshine> (manual add syntax `<ip>:47989`)
- <https://github.com/LizardByte/Sunshine/issues/1881> (port list incl. UDP 5353)

---

## 2. Available container images

| Image | Registry path | Status | Notes |
|---|---|---|---|
| **LizardByte official** | `lizardbyte/sunshine:<ver>-<os>` / `ghcr.io/lizardbyte/sunshine:<ver>-<os>` | Actively published (e.g. `v2026.1017.22144-ubuntu-24.04`, `latest-ubuntu-24.04`); amd64 + arm64 | Officially "not intended to use as a standalone container at this point ... experimental" — it's a **base image**: entrypoint runs `sunshine` only; you must add Xorg/Wayland/apps yourself (`FROM lizardbyte/sunshine`, install a display server + desktop). Persists config at `/config`; env `PUID`/`PGID`/`TZ`; wants `--device /dev/dri`, `--ipc=host`. |
| **GOW legacy Sunshine** | `ghcr.io/games-on-whales/sunshine:edge` (Docker Hub mirror: `gameonwhales/sunshine`) | Stale — last published >1 yr ago; removed from current repo layout | Requires `xorg` + `pulseaudio` sidecar containers sharing `/tmp/.X11-unix` and pulse socket; `privileged: true`; env `SUNSHINE_USER`, `SUNSHINE_PASS`, `GOW_REQUIRED_DEVICES`, `XDG_RUNTIME_DIR`, `LOG_LEVEL`. Reference compose at commit `2e44229`. |
| **Wolf (GOW, current)** | `ghcr.io/games-on-whales/wolf:stable` | Actively maintained | Single container that spawns app containers via `/var/run/docker.sock`. Needs `network_mode: host`, `/dev/dri`, `/dev/uinput`, `/dev/uhid`, `-v /dev:/dev`, `-v /run/udev:/run/udev`, `device_cgroup_rule "c 13:* rmw"`, config at `/etc/wolf`. App/desktop images: `ghcr.io/games-on-whales/<app>` — incl. **`xfce`** (full desktop — the right pick for a "Linux dev desktop"), `steam`, `firefox`, `retroarch`, `kodi`, `lutris`, `heroic-games-launcher`, `es-de`, `pegasus`, `prismlauncher`, `plex`, `emby`, `youtube`. WSL2 documented but "hasn't been properly tested". |
| **linuxserver.io** | — | **No dedicated sunshine image.** Their `lscr.io/linuxserver/steamos` image bundled Sunshine + gamescope but is now **deprecated/archived**. | <https://docs.linuxserver.io/deprecated_images/docker-steamos/> |
| Selkies / other | `ghcr.io/selkies-project/...` | Alternative project | WebRTC-based (browser client, not Moonlight protocol) — out of scope unless requirements change. |

Sources for the table: <https://docs.lizardbyte.dev/projects/sunshine/latest/md_DOCKER__README.html>,
<https://hub.docker.com/r/lizardbyte/sunshine>, <https://github.com/LizardByte/Sunshine/pkgs/container/sunshine>,
<https://github.com/games-on-whales/gow/pkgs/container/sunshine>,
<https://github.com/games-on-whales/wolf/>, <https://games-on-whales.github.io/wolf/stable/user/quickstart.html>,
<https://games-on-whales.github.io/wildlife/>, <https://github.com/games-on-whales/gow/tree/master/apps>,
<https://hub.docker.com/u/gameonwhales>.

**Best candidate for "Sunshine serving a containerized Linux desktop":**
`ghcr.io/games-on-whales/wolf:stable` + the `xfce` (and/or `steam`) app images. It is the
only option that (a) is actively maintained, (b) already solves the virtual-display,
audio, and input problems, and (c) is purpose-built for Docker hosts — the upstream
LizardByte docs themselves point at games-on-whales as the reference Docker deployment.
If literally-Sunshine is required, plan B is `lizardbyte/sunshine` as a base image with
Xorg/Xvfb added, accepting "experimental" status; the stale `games-on-whales/sunshine:edge`
is plan C.

---

## 3. Ports

Full exact table in `ports-and-config.md`. Summary (defaults; base port 47989 is
configurable via `port =` and everything offsets from it):

- TCP 47984 (HTTPS, Moonlight pairing/API), 47989 (HTTP), 47990 (HTTPS **Web UI**),
  48010 (RTSP setup)
- UDP 47998 (video), 47999 (control), 48000 (audio), 48002 (mic, reserved/unused),
  48010 (RTSP fallback, optional)
- UDP 5353 mDNS (auto-discovery only; ineffective through Docker Desktop NAT — use
  Moonlight "Add Host Manually" `<tailscale-ip>:47989`)

Correction to the brief: the **Web UI is 47990**, not 47984 — 47984 is the HTTPS
endpoint the Moonlight client itself talks to.

Official source (docs PDF, port-offset table):
<https://docs.lizardbyte.dev/_/downloads/sunshine/en/v0.18.4/pdf/>; corroborating:
<https://github.com/LizardByte/Sunshine/issues/1881>,
<https://github.com/LizardByte/Sunshine/pull/833> (48002 mic + RTSP UDP fallback).

### Pairing flow (Moonlight ↔ Sunshine)

1. Moonlight client → "Add Host Manually" → `<ip>` (or `<ip>:47989`).
2. Moonlight shows a 4-digit **PIN**.
3. Browse to the Sunshine web UI `https://<host>:47990` → **PIN** page → enter it.
4. Client pairs and the app list (Desktop/Steam or configured `apps.json` entries) appears.

Web UI first-run forces creation of admin credentials interactively; headless alternative:
`sunshine --creds <username> <password>` (resets/creates the stored credentials — usable
via `docker exec` for a containerized deploy).
- <https://github.com/LizardByte/Sunshine/blob/master/docs/troubleshooting.md> ("Forgotten Credentials")
- <https://www.mintlify.com/LizardByte/Sunshine/guides/troubleshooting>

**Wolf pairing differs:** no web UI login — Wolf logs a one-time URL
`http://<host>:47989/pin/#<hex>` where the PIN is entered; paired clients land on
"Wolf UI" (profile/app picker).
- <https://games-on-whales.github.io/wolf/stable/user/quickstart.html> ("Moonlight pairing")

---

## 4. Config persistence

- Container config dir: **`/config`** (the image's stated volume; also Sunshine's
  documented default config dir "when running under Docker").
  Contents worth knowing:
  - `sunshine.conf` — main config file (see below)
  - `apps.json` — `file_apps`, the Moonlight app launcher list
  - `sunshine_state.json` — `credentials_file` + `file_state`: web-UI user credentials
    and paired-client state live here
  - `credentials/cakey.pem` + `credentials/cacert.pem` — `pkey`/`cert`: RSA-2048 keypair
    used for the web UI TLS **and** Moonlight pairing
- Wolf config dir: **`/etc/wolf`** → `cfg/config.toml` (hostname shown in Moonlight,
  `paired_clients`, `profiles`, gstreamer pipeline overrides), `key.pem`/`cert.pem`.
- GOW legacy image: state home is `/home/retro/` (mounted volume), creds via
  `SUNSHINE_USER`/`SUNSHINE_PASS` env.

`sunshine.conf` options worth templating (defaults shown):
`port = 47989`, `sunshine_name = <hostname>`, `upnp` (default `disabled` — keep off;
host publishes ports itself), `address_family = ipv4|both`, `external_ip` (auto;
set to the Tailscale IP if auto-detect picks the wrong interface),
`origin_web_ui_allowed = lan` — **note: Tailscale CGNAT addresses (100.64.0.0/10) are not
RFC1918 "LAN"; if web-UI access over Tailscale is refused, set `wan` or reach the UI via
`localhost` SSH port-forward**, `encoder = software|vaapi|nvenc|...`,
`hevc_mode`/`av1_mode`, `min_log_level`, `global_prep_cmd`.
Source: <https://github.com/LizardByte/Sunshine/blob/master/docs/configuration.md>

---

## 5. Native-install alternative (Windows)

Officially supported install paths on dtop202311:

- `winget install --id=LizardByte.Sunshine -e` (machine-scope MSI; silent variant:
  `msiexec /i Sunshine-Windows-AMD64-installer.msi /quiet /norestart`)
- Or download `Sunshine-Windows-AMD64-installer.msi` from GitHub releases — the MSI is
  the preferred artifact; a "lite" portable zip exists but upstream explicitly warns it
  is not recommended/unsupported.
- Installer registers a Windows service (autostart script included), adds firewall rules
  via bundled `scripts/add-firewall-rule.bat`; config lives in
  `%ProgramFiles%\Sunshine\config`.
- Sources: <https://www.mintlify.com/LizardByte/Sunshine/installation/windows>,
  <https://github.com/LizardByte/Sunshine/blob/HEAD/docs/getting_started.md>,
  <https://github.com/microsoft/winget-pkgs/tree/master/manifests/l/LizardByte/Sunshine>,
  <https://wingetly.io/apps/lizard-byte/sunshine>

**What native gains:** real Windows desktop capture (DXGI Desktop Duplication `ddx`, or
`wgc`), native GPU encode — NVENC / AMF / QuickSync / Media Foundation per the feature
matrix, virtual gamepad drivers (Virtual HID Broker / ViGEmBus), HDR capture, and a
system tray. It is upstream's primary supported path for Windows.

**Sunshine-in-WSL2 (native Linux package inside a WSL distro):** not documented or
supported upstream. The one community attempt (GOW issue #13) got Sunshine running under
WSL2 but KMS capture and uinput failed. The upstream maintainer's own position: "Sunshine
works perfectly well natively on Windows, and why would you run games in a Docker
container via proton ... when you can just run them natively". Treat WSL2-native as
unsupported.

---

## 6. Web UI / HTTPS / credentials handoff

- Web UI: `https://<host>:47990`, self-signed cert (generated from `pkey`/`cert`,
  RSA-2048 recommended for Moonlight compatibility). First run presents a
  "create admin account" prompt.
- Headless credential provisioning (for vault-managed handoff):
  `docker exec <container> sunshine --creds <user> <pass>` — or run the binary once
  before starting the service; creds persist in `/config/sunshine_state.json`.
- GOW legacy image: `SUNSHINE_USER` / `SUNSHINE_PASS` env vars (set from vault).
- Wolf: no static admin login; pairing is the PIN-URL flow above. Profiles can carry an
  optional `pin` in `config.toml`.
- Access control: `origin_web_ui_allowed` defaults to `lan`; over Tailscale, either set
  `wan` (behind the HTTPS + creds) or port-forward `47990` over SSH. `bind_address`
  exists but must be an address the *container/VM* has — not useful for restricting to
  Tailscale directly; rely on published-port binding or firewall rules instead.
- Sources: configuration.md (`pkey`, `cert`, `credentials_file`, `origin_web_ui_allowed`,
  `bind_address`), troubleshooting.md (`--creds`), Wolf quickstart.

---

## 7. Recommendation

| Goal | Recommended approach | Why |
|---|---|---|
| **(a) Stream the actual Windows desktop of dtop202311** | **Native Windows install** (`winget install LizardByte.Sunshine`, Ansible `win_package`/win_shell) | Only path that can capture the Windows desktop at all. Adds full GPU encode (NVENC/AMF/QSV), gamepad drivers, HDR, and upstream support. The container path structurally cannot do this. |
| **(b) A streaming Linux dev desktop running on the Windows box** | **Wolf container** (`ghcr.io/games-on-whales/wolf:stable` + `ghcr.io/games-on-whales/xfce:edge`) | Purpose-built for exactly this: on-demand containerized virtual desktops, no Xorg babysitting, actively maintained, documents WSL2. Alternatives if literal Sunshine required: `lizardbyte/sunshine:<ver>-ubuntu-24.04` base image + Xvfb/Xorg + desktop (experimental); or stale GOW `sunshine:edge` + `xorg` + `pulseaudio` stack (works by design but unmaintained). |

Honest caveats for goal (b) on dtop202311:

- Encoding will most likely be **software x264** unless the WSL2 VA-API-d3d12 or NVENC
  paths pan out — plan CPU accordingly (and prefer H.264; HEVC/AV1 software encode is heavy).
- **Gamepads probably won't work** without uinput in the WSL2 kernel (mouse/keyboard OK).
  Verify `ls /dev/uinput` early.
- Wolf needs `network_mode: host` → requires Docker Desktop ≥ 4.34 with the opt-in
  "Enable host networking" setting; alternatively bind-publish the port ranges for the
  Sunshine-based options (works fine — ports, not host networking).
- No mDNS discovery; use Moonlight "Add Host Manually" with the Tailscale IP — which is
  also what the Tailscale-only reachability implies anyway.
- If the *real* requirement turns out to be "remote into this Windows desktop",
  deploy native Sunshine and skip containers entirely.
