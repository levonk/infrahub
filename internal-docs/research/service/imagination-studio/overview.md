# Imagination Studio — Overview

**Upstream**: https://github.com/Keys-Wasserman/Imagination-Studio-by-keys-Wasserman
(Apache-2.0, ~1.1k★, active — 907 commits, v4.2.1 as of 2026-11-16)

An AI film studio powered by TensorFold: plan a film (Slate workflow),
generate pictures, video, voices and music, then edit and export.
Web app on `http://127.0.0.1:7870` with a job queue, memory guard,
MCP tools (`mcp/README.md`) and a remote-worker model ("Sparks" tab).

Supported platforms upstream:

- **NVIDIA DGX Spark** (GB10, 128 GB unified memory, DGX OS + Docker for
  prebuilt engines) — `oneshot-setup-spark.sh` → `oneshot-setup-cuda.sh`
- **Apple silicon Mac** (macOS 26+, M5-family for fast video) — `oneshot-setup.sh --app`
- **Windows 11 on Arm + RTX Spark N1X** (native only, no WSL, no x86) —
  `oneshot-setup-rtx-spark-n1x.ps1`

## Components

| Component | What | Where it runs |
|---|---|---|
| Studio app | Python (FastAPI/uvicorn) web app — planning, queue, library, QA | head machine |
| FastH3 | TensorFold int8 video engine (MiniMax H3 derivative) | GPU machine |
| Managed ComfyUI | picture models (Qwen-Image-2.1, FLUX3-K, MOSS, H3-Image), spawned per-render by the app on `:8190` (Spark) / `:8191` (Mac) | GPU machine |
| Drama3 | Fish Audio Drama 3 voices | GPU machine |
| Music3 / YuE2 | MiniMax Music 3 / m-a-p YuE2 songs | GPU machine |
| Bolt | NVIDIA Nemotron 3.5 Bolt 24 GB "brain" engine | GPU machine |
| memguard | per-user memory guard (systemd user unit / launchd / logon task) | GPU machine |

## Head/worker model (app/sparks.py)

A job carries `sparks` (1–5+local): how many machines render for it, the head
counted as one. Workers run a **full copy of the same app** on `127.0.0.1:7870`;
the head reaches them through SSH tunnels it opens itself, pushes its own code
via rsync when versions differ, and fetches rendered clips back into its own
`STUDIO_HOME`.

`KINDS = ("video",)` — **only single video clips are dispatchable**.
`here_only()` pins to the head: long-video chains, `studio` kind, pictures,
edits, Library actions, exports, voice, music, soundtrack, finish, graphics,
hlg. This is what forces the head onto the GPU machine for full features.

## Remote/offload knobs found in code

- `SPARK_COMFY_URL` / `STUDIO_COMFY_URL` — point the app's ComfyUI calls at
  another machine's ComfyUI (or Comfy Cloud with `STUDIO_COMFY_API_KEY`,
  https-only for keys).
- `HOST=0.0.0.0` — listen beyond loopback; access key enforced for
  non-loopback clients.
- `app/remote.py` — read/fetch a finished job from *another Studio's* API
  (`/api/jobs/<id>`, `/files/<path>` + `X-Studio-Key`).

## Local clone

Reference checkout used for this research: `/tmp/imagination-studio-src`
(shallow clone of `main`, 2026-11-16).
