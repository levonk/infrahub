# Sunshine / Moonlight — ports, volumes, env vars, deploy snippets

Reference for the infrahub Ansible role (host: **dtop202311**, Docker Desktop WSL2).
Main findings + recommendation: `sunshine-docker-windows.md`.

> Project rule reminder: all ports/IPs in the eventual role must come from
> `infra_port_*` / `infra_*` variables, not literals. The literals below are the
> upstream defaults the variables should mirror.

## 1. Port table (Sunshine, defaults)

Base port is `port = 47989` in `sunshine.conf`; every other port is an offset from it
(range allowed: 1029–65514). Changing `port` shifts the whole family.

| Port | Proto | Offset | Purpose |
|---|---|---|---|
| 47984 | TCP | -5 | HTTPS — Moonlight client API / pairing handshake |
| 47989 | TCP | 0 (base) | HTTP — Moonlight client API; "Add Host Manually" default port |
| 47990 | TCP | +1 | **Web UI (HTTPS)** — `https://<host>:47990` |
| 48010 | TCP | +21 | RTSP setup (stream negotiation) |
| 47998 | UDP | +9 | Video (RTP) |
| 47999 | UDP | +10 | Control (input, ENet) |
| 48000 | UDP | +11 | Audio (Opus) |
| 48002 | UDP | +13 | Microphone — reserved/unused by current Moonlight; harmless to publish |
| 48010 | UDP | +21 | RTSP-over-UDP fallback — not required by current Moonlight clients |
| 5353 | UDP | n/a | mDNS auto-discovery (optional; does NOT traverse Docker Desktop NAT or Tailscale — rely on manual host add) |

Sources:
- Official offset table (Sunshine docs PDF): <https://docs.lizardbyte.dev/_/downloads/sunshine/en/v0.18.4/pdf/>
- Port list incl. 5353/48002: <https://github.com/LizardByte/Sunshine/issues/1881>
- Mic port + RTSP UDP fallback: <https://github.com/LizardByte/Sunshine/pull/833>
- Firewall examples: <https://www.mintlify.com/LizardByte/Sunshine/deployment/security>
- Manual add `<ip>:47989`: <https://nixos.wiki/wiki/Sunshine>

The upstream Docker docs publish: `47984-47990/tcp`, `48010` (TCP — publishing UDP too is
harmless), `47998-48000/udp`. That is the minimal working set; add `48002/udp` for
completeness and `5353/udp` only if you also run an mDNS reflector (not recommended).
Source: <https://docs.lizardbyte.dev/projects/sunshine/latest/md_DOCKER__README.html>

Wolf uses the same Moonlight ports but is deployed with `network_mode: host`
(no `ports:` block). On Docker Desktop this requires ≥ v4.34 + opt-in
"Settings → Resources → Network → Enable host networking" (L4 only).
Sources: <https://games-on-whales.github.io/wolf/stable/user/quickstart.html>,
<https://docs.docker.com/engine/network/drivers/host/>

## 2. Volumes / devices / env per image

### lizardbyte/sunshine (official base image — "experimental", standalone use unsupported)

- Image: `lizardbyte/sunshine:<SUNSHINE_VERSION>-<SUNSHINE_OS>` e.g.
  `lizardbyte/sunshine:latest-ubuntu-24.04` or pinned `v2026.1017.22144-ubuntu-24.04`;
  GHCR: `ghcr.io/lizardbyte/sunshine:<same tags>`. amd64 + arm64.
- Volume: `<host-path>:/config` (sunshine.conf, apps.json, sunshine_state.json,
  credentials/*.pem all live here)
- Devices/caps: `--device /dev/dri/`, `--ipc=host`; for WSL2 VA-API experiments also
  `--device /dev/dxg`, `-v /usr/lib/wsl:/usr/lib/wsl`,
  `-e LIBVA_DRIVER_NAME=d3d12`, `-e LD_LIBRARY_PATH=/usr/lib/wsl/lib`
- Env: `PUID`, `PGID`, `TZ`
- Entrypoint is bare `sunshine` — it has **no display server or apps**; you are expected
  to derive an image (`FROM lizardbyte/sunshine` + Xorg/Wayland/desktop + your apps).
- Source: <https://docs.lizardbyte.dev/projects/sunshine/latest/md_DOCKER__README.html>,
  <https://hub.docker.com/r/lizardbyte/sunshine>

### ghcr.io/games-on-whales/sunshine:edge (legacy GOW stack — stale, >1 yr old)

Needs sibling `ghcr.io/games-on-whales/xorg:edge` and `.../pulseaudio:edge` containers:

```yaml
sunshine:
  image: ghcr.io/games-on-whales/sunshine:edge
  privileged: true
  ipc: host
  ports:
    - "47984-47990:47984-47990/tcp"
    - "48010:48010"
    - "47998-48000:47998-48000/udp"
  volumes:
    - <xorg-socket-dir>:/tmp/.X11-unix        # shared X11 socket from xorg container
    - <pulse-socket-host>:<pulse-socket-guest> # shared PulseAudio socket
    - <state-dir>:/home/retro/                 # sunshine state + configs
    - /run/dbus:/run/dbus:ro                   # optional: avahi/mDNS discovery
  environment:
    LOG_LEVEL: info
    GOW_REQUIRED_DEVICES: /dev/uinput /dev/input/event* /dev/dri/*
    SUNSHINE_USER: <web-ui-user>    # headless web-UI credentials
    SUNSHINE_PASS: <web-ui-pass>
    XDG_RUNTIME_DIR: /tmp/.X11-unix
```

Source: <https://github.com/games-on-whales/gow/blob/2e442292d79b9d996f886b8a03d22b6eb6bddf7b/compose/streamers/sunshine.yml>
(full stack also needs the `xorg` and `pulseaudio` services from `compose/platforms/` of
the same commit)

### ghcr.io/games-on-whales/wolf:stable (recommended container path)

```yaml
wolf:
  image: ghcr.io/games-on-whales/wolf:stable
  network_mode: host            # Docker Desktop ≥4.34 + opt-in setting; L4 only
  restart: unless-stopped
  volumes:
    - <etc-wolf>:/etc/wolf:rw                    # config.toml, key.pem, cert.pem
    - /var/run/docker.sock:/var/run/docker.sock:rw
    - /dev/:/dev/:rw
    - /run/udev:/run/udev:rw
  devices:
    - /dev/dri
    - /dev/uinput      # absent on stock WSL2 kernels — see caveat
    - /dev/uhid
  device_cgroup_rules:
    - 'c 13:* rmw'
```

WSL2 note from upstream quickstart: "Running Wolf in WSL2 hasn't been properly tested";
dropping `/dev/uinput` + `/dev/uhid` yields a reduced mode — mouse/keyboard only,
no gamepads. Config: `/etc/wolf/cfg/config.toml` (`hostname` = Moonlight display name,
`paired_clients`, `profiles`, gstreamer pipeline). Key env: `WOLF_CFG_FILE`,
`WOLF_PRIVATE_KEY_FILE`, `WOLF_PRIVATE_CERT_FILE`, `WOLF_RENDER_NODE`
(default `/dev/dri/renderD128`), `HOST_APPS_STATE_FOLDER`, `WOLF_LOG_LEVEL`,
`WOLF_DEFAULT_RUN_UID`/`WOLF_DEFAULT_RUN_GID` (app containers run 1000:1000).
Desktop app for Moonlight entry: `ghcr.io/games-on-whales/xfce:edge` (full XFCE desktop;
Wolf downloads app images on first launch — first connection shows a black screen while
pulling).
Sources: <https://games-on-whales.github.io/wolf/stable/user/quickstart.html>,
<https://games-on-whales.github.io/wolf/stable/user/configuration.html>,
<https://games-on-whales.github.io/wildlife/apps/xfce/>

## 3. sunshine.conf — options worth templating

File: `/config/sunshine.conf` (in-container). Write with Ansible `template`/`copy` +
`no_log` where secrets appear; restart container on change.

```ini
# identity / network
sunshine_name = {{ sunshine_display_name }}      # shown in Moonlight host list
port = {{ sunshine_base_port }}                  # default 47989; shifts whole family
upnp = disabled                                  # keep disabled — we publish ports ourselves
address_family = ipv4                            # or 'both' for IPv6
external_ip = {{ sunshine_advertise_ip }}        # e.g. Tailscale IP; default = auto-detect
# origin_web_ui_allowed = lan                    # default 'lan'; Tailscale 100.64/10 is
                                                 # NOT RFC1918 — use 'wan' or SSH-forward
                                                 # localhost:47990 for admin access
# encoder — choose per capability probe; 'software' is the safe default on WSL2
encoder = software                               # nvenc|quicksync|amdvce|vaapi|vulkan|software
hevc_mode = 0                                    # advertise per-encoder capability
# min_log_level = info
```

Other file paths inside `/config` (defaults; keep them): `file_apps = apps.json`,
`credentials_file = sunshine_state.json`, `file_state = sunshine_state.json`,
`pkey = credentials/cakey.pem`, `cert = credentials/cacert.pem` (RSA-2048 — also used
for Moonlight pairing certs), `log_path = sunshine.log`.
Source: <https://github.com/LizardByte/Sunshine/blob/master/docs/configuration.md>

## 4. Headless credentials (vault handoff)

```bash
# after container start — sets/resets web-UI admin credentials
docker exec <sunshine-container> sunshine --creds '<user>' '<pass>'
```

Creds persist in `/config/sunshine_state.json`. Per project rules the password comes
from the client vault (`infrahub-levonk-all.vault.yml`); hand the user an
`edit-vault.sh` command rather than touching the vault.
Source: <https://github.com/LizardByte/Sunshine/blob/master/docs/troubleshooting.md>

## 5. Sample tasks

### community.docker.docker_container (Sunshine-family image)

```yaml
- name: Sunshine container
  community.docker.docker_container:
    name: sunshine
    image: "{{ sunshine_image }}"              # e.g. lizardbyte/sunshine:{{ sunshine_tag }}
    restart_policy: unless-stopped
    ipc_mode: host
    devices:
      - /dev/dri:/dev/dri
    env:
      PUID: "{{ sunshine_puid }}"
      PGID: "{{ sunshine_pgid }}"
      TZ: "{{ sunshine_tz }}"
    volumes:
      - "{{ sunshine_config_dir }}:/config"
    published_ports:
      - "{{ infra_port_sunshine_https }}:47984/tcp"
      - "{{ infra_port_sunshine_http }}:47989/tcp"
      - "{{ infra_port_sunshine_webui }}:47990/tcp"
      - "{{ infra_port_sunshine_rtsp }}:48010/tcp"
      - "{{ infra_port_sunshine_video }}:47998/udp"
      - "{{ infra_port_sunshine_control }}:47999/udp"
      - "{{ infra_port_sunshine_audio }}:48000/udp"
      - "{{ infra_port_sunshine_mic }}:48002/udp"
```

### community.docker.docker_container (Wolf)

```yaml
- name: Wolf container
  community.docker.docker_container:
    name: wolf
    image: ghcr.io/games-on-whales/wolf:{{ wolf_tag }}   # 'stable'
    network_mode: host
    restart_policy: unless-stopped
    devices:
      - /dev/dri:/dev/dri
      # - /dev/uinput:/dev/uinput   # only if present in the WSL2 kernel
      # - /dev/uhid:/dev/uhid
    device_cgroup_rules:
      - "c 13:* rmw"
    volumes:
      - "{{ wolf_config_dir }}:/etc/wolf:rw"
      - /var/run/docker.sock:/var/run/docker.sock:rw
      - /dev/:/dev/:rw
      - /run/udev:/run/udev:rw
    env:
      WOLF_LOG_LEVEL: "{{ wolf_log_level }}"
```

### docker run equivalents (for smoke-testing on the host)

```bash
# Sunshine-family
docker run -d --name sunshine --restart unless-stopped --ipc=host \
  --device /dev/dri/ \
  -e PUID=1000 -e PGID=1000 -e TZ=UTC \
  -v /opt/sunshine/config:/config \
  -p 47984-47990:47984-47990/tcp -p 48010:48010 -p 48010:48010/udp \
  -p 47998-48000:47998-48000/udp -p 48002:48002/udp \
  lizardbyte/sunshine:latest-ubuntu-24.04

# Wolf
docker run -d --name wolf --network=host --restart unless-stopped \
  -v /etc/wolf:/etc/wolf:rw \
  -v /var/run/docker.sock:/var/run/docker.sock:rw \
  -v /dev/:/dev/:rw -v /run/udev:/run/udev:rw \
  --device /dev/dri/ --device /dev/uinput --device /dev/uhid \
  --device-cgroup-rule "c 13:* rmw" \
  ghcr.io/games-on-whales/wolf:stable
```

### Native Windows alternative (for goal "stream the actual Windows desktop")

```powershell
winget install --id=LizardByte.Sunshine -e --accept-package-agreements --accept-source-agreements
# MSI silent: msiexec.exe /i Sunshine-Windows-AMD64-installer.msi /quiet /norestart
# Firewall rules + service are installed by the installer; web UI https://localhost:47990
```

Source: <https://www.mintlify.com/LizardByte/Sunshine/installation/windows>

## 6. Pre-flight checks for the role (dtop202311)

1. `wsl --status` / Docker Desktop ≥ 4.34 if Wolf + `network_mode: host` is chosen
   (and "Enable host networking" toggled on).
2. `ls /dev/uinput /dev/uhid` inside a test container — gates gamepad support.
3. `ls /dev/dri /dev/dxg` — gates VA-API-d3d12 encode experiments; software encode
   needs nothing.
4. Decide pairing UX: Sunshine web UI PIN (47990, needs creds) vs Wolf logged PIN URL
   (`http://<host>:47989/pin/#...`).
5. mDNS will not work → document "Add Host Manually → `<tailscale-ip>`" for clients.
