# Imagination Studio — Configuration

## Install flags chosen: `--all --h3-image` (~423 GB)

`--all` expands to: SWAP, REF2VA, H3_BASE, IMAGE_EDIT, FLUX3, MOSS, MUSIC,
YUE2, SOUND, BOLT, VOICE, MOTION, TRAIN, GRAPHICS, FINISH.
`--h3-image` is explicitly NOT part of `--all` — passed separately.

| Flag | Adds | Size | License flag |
|---|---|---|---|
| (core) | FastH3 video, Qwen-Image-2.1 Turbo pictures, Drama3 voice | ~125 GB | see security.md |
| `--image-edit` | Qwen-Image-2.1 40-step base | +14 GB | non-commercial |
| `--flux3` | FLUX3-K Fast+Full, encoder, upsampler, decoder | +41 GB | gated; non-commercial / outputs <$5M |
| `--moss` | MOSS-Image | +30 GB | Apache-2.0 |
| `--h3-image` | MiniMax-H3-Image pictures | +23 GB | territory limits |
| `--music` | MiniMax Music 3 + TensorFold engine | +22 GB | <$20M rev OK |
| `--yue2` | YuE2 songs | +13 GB | weights CC BY-NC |
| `--sound` | Stable Audio Open + MMAudio foley | +11 GB | SAO gated; MMAudio CC-BY-NC |
| `--bolt` | Nemotron 3.5 Bolt brain + engine | +25 GB | OpenMDW |
| `--swap` | Character-swap LoRA + Ref2VA int8 | +21 GB | community |
| `--train` | musubi-tuner LoRA training | +14 GB | Apache/H3 |
| `--motion` | pose/camera/depth previs | +0.5 GB | — |
| `--graphics`/`--finish` | motion graphics, export finishing | varies | — |

## Environment variables (app/server.py, scripts/app.sh, app/*.py)

| Var | Purpose | Deploy value |
|---|---|---|
| `HOST` | bind address (default `127.0.0.1`) | `<kckinai tailscale IP>` → tailnet-only |
| `PORT` | app port (default `7870`) | `7870` |
| `STUDIO_HOME` | studio folder (default `~/ImaginationStudio`) | TBD — PRD decision |
| `PREFIX` | install prefix (models, venv, ComfyUI) | set by installer |
| `SPARK_COMFY_URL` | remote ComfyUI endpoint | unset (local managed :8190) |
| `SPARK_COMFY_PORT` | managed ComfyUI port (default `8190`) | `8190` (loopback) |
| `STUDIO_ALLOWED_HOSTS` | extra trusted Host headers | unset (ts.net trusted natively) |
| `STUDIO_TRUST_TAILNET` | `1` lets tailnet clients in w/o key | optional — key still recommended |
| `STUDIO_ACCESS_KEY` | `off` disables the key check | leave `on` |
| `STUDIO_MEMORY_MANAGER` | `off` disables admission/watch | `on` (worker eligibility needs it) |
| `STUDIO_MEMORY_GUARD` | `strict`/`warn` guard behaviour | default |
| `IMAGE_MODEL` | picture model pick (e.g. `moss-image`, `h3-image`) | runtime/UI |
| `MUSIC3_BACKEND` | `cuda` (built engine) or `comfy` (nodes) | `cuda` once built |
| `MUSIC3_WEIGHTS` | `bf16` for checkpoint weights | default int8 |
| `QWEN_MODEL_DIR` / `H3_MODEL_DIR` | model dir overrides | unset (PREFIX default) |

## Access key mechanics (app/access.py)

- Key auto-generated once in `<STUDIO_HOME>/access-key` (0600), persists
  across restarts/updates.
- Non-loopback clients need it: cookie `studio_key_<port>` (set via
  `/?key=<key>` or Settings → Access key QR), or `X-Studio-Key` /
  `Authorization: Bearer` header.
- `scripts/studio-key.sh` prints key + addresses on the host.
- WriteGuard also enforces `trusted_host()` on every request (localhost /
  numeric IP / own names / `*.ts.net` / `STUDIO_ALLOWED_HOSTS`) and
  Origin/`Sec-Fetch-Site` on mutations — DNS-rebinding + CSRF hardened.
