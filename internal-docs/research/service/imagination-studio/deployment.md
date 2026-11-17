# Imagination Studio — Deployment Design

## Decision (confirmed with user 2026-11-16)

**Native install on kckinai (DGX Spark, GB10) — head and GPU worker in one.
Tailnet-only exposure. Nothing deployed to Windows.**

Install command: `bash oneshot-setup-spark.sh --all --h3-image` (~423 GB).

### Why this topology

`KINDS=("video")` means voice (Drama3), music (Music3/YuE2), long-video
chains, `studio` kind and LoRA training only run where the **head** is, and
they need aarch64-CUDA engines that cannot run in an amd64 no-GPU container.
A container head on dtop202311 (amd64 Windows Docker Desktop) would lose
those kinds — see `alternatives.md`. Head-on-Spark is upstream's primary
supported path: every job kind works, no container gymnastics.

"Everything else in a container on Windows" therefore evaporates — the
UI/queue/library IS the head app, and the head must sit on the GB10.
dtop202311 is a browser client: `http://kckinai.tale-grouper.ts.net:7870`.

## Target

| Item | Value |
|---|---|
| Host | `kckinai` — `192.168.2.21` LAN, `kckinai.tale-grouper.ts.net` |
| Inventory | `levonk/.../inventories/localnet.yml` → `localnet_hosts` |
| Run user | `lk` (existing `localnet_kckinai_ansible_user`) |
| Install type | **native** (same pattern as `ai-comfyui`; GB10 workloads run natively) |

## Prerequisites verified (2026-11-16)

| Check | Result |
|---|---|
| Disk | 3.0 T free on `/` (need ~423 GB) |
| Unified memory | 114 GB available; box idle (no vLLM/ComfyUI loaded) |
| HF auth | `~lk/.cache/huggingface/token` valid, account `Thren`; gated repos verified accessible (flux-3-image-klein-comfy 302 on real file, stable-audio-open-1.0 200); drama-3 confirmed ungated |
| Tailnet | ssh via `kckinai.tale-grouper.ts.net` works with `~/.ssh/2016mbpro-zentries-localcloud` |

## Runtime layout

- App: `HOST=<kckinai tailscale IP> PORT=7870` — binds tailnet interface
  only (tailnet-only by binding, not just by key). `*.ts.net` already passes
  `trusted_host()`; a Traefik FQDN would need `STUDIO_ALLOWED_HOSTS` (n/a for
  tailnet-only).
- `STUDIO_HOME` — projects/renders (default `~/ImaginationStudio`; decide:
  lk's home vs `infra_storage_services_dir` convention → open question for PRD).
- Managed ComfyUI: app-spawned on `127.0.0.1:8190` — no collision with the
  existing native ComfyUI on `:8188`.
- Models: one tree under `$PREFIX` (`ComfyUI/models/<Family>-Comfy/`),
  internally deduplicated (e.g. 27 GB qwen3vl_32b text encoder shared by
  FastH3 + H3-Image, fetched once). `hf download --local-dir` → no HF-cache
  double-store. **No overlap with existing ComfyUI tree** (Wan2.2/SDXL at
  `/opt/localnet/services/comfyui`, 37 GB).
- memguard: per-user systemd unit installed by setup (keep default — does
  NOT stop foreign procs; `--memguard-stop-foreign` would let it kill vLLM).
- App service: upstream ships **no** unit — role must add a `systemd --user`
  service + `loginctl enable-linger lk` (precedent: `scripts/memguard.py
  install` creates user units the same way).

## Ansible plan (per infrahub-add-new-service.md)

- Role `ai-imagination-studio` (native-install role on `localnet_hosts`,
  follows `ai-comfyui` precedent — exception to the container pattern).
  Tasks: deps (git ffmpeg python3-venv rsync openssh), checkout at pinned ref,
  run `oneshot-setup-spark.sh --all --h3-image` as `lk` (idempotent — the
  installer itself is re-runnable/`--verify`-able; long-running model
  downloads, consider async + poll or a documented first-run step), systemd
  user unit + linger, tailnet bind env.
- Playbooks: `deploy-imagination-studio.yml` + `validate-imagination-studio.yml`,
  `--limit kckinai`; `just ansible-deploy-imagination-studio` recipe +
  devbox script.
- infra vars: `infra_port_ai_studio_host/container` (7870), managed-comfy
  port (8190, loopback only — register for conflict tracking),
  `infra_storage_studio_*` dirs. Check ports.yml — 7870/8190 currently free.
- Validate: `GET /api/spark/self` on tailnet IP, units enabled, port bound to
  tailscale IP only, disk headroom post-install.
- **No vault items needed** — persisted hf auth already on host under `lk`.
  Role must never cat/log `~/.cache/huggingface/token`.

## Coexistence on kckinai

- Studio memory guard measures each job's measured peak vs *available*
  unified memory; unloads its own idle modules, waits, refuses naming what
  holds memory. vLLM/ComfyUI contention → renders queue/wait, never OOM.
  Measured FastH3 clip peak ~58 GB.
- `--h3-image` note: not included in `--all`; requires explicit flag (done).
- Upgrades: `git pull` in a clean clone + `bash oneshot-setup.sh --upgrade`.
