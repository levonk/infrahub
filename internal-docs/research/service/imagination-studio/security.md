# Imagination Studio — Security

## Secrets

| Item | Storage | Note |
|---|---|---|
| HF token | already persisted at `~lk/.cache/huggingface/token` (0600), account `Thren` | **No vault item needed.** Role must never log/cat it. Verified access to both gated repos (2026-11-16). |
| Studio access key | auto-generated `<STUDIO_HOME>/access-key` | per-studio secret; retrieve via `scripts/studio-key.sh` or Settings → Access key |
| Vault | none | — |

## Exposure

- Tailnet-only **by binding**: `HOST=<kckinai tailscale IP>` — not just
  key-gated; the app never listens on LAN/wildcard. Chosen over `HOST=0.0.0.0`.
- Belt-and-suspenders already in the app: per-studio access key for all
  non-loopback clients, `trusted_host()` DNS-rebinding guard on every
  request (numeric IPs and `*.ts.net` pass), Origin/Sec-Fetch-Site check on
  mutations.
- `STUDIO_TRUST_TAILNET=1` exists to skip the key on the tailnet — keep the
  key anyway (defense in depth if tailnet ACLs change).

## Model license flags (user accepted both HF gates 2026-11-16)

| Model | License | Constraint |
|---|---|---|
| MiniMax H3 / H3-Image / FastH3 | MiniMax Community License | **territory limits — EU/UK/KR/US need MiniMax's own licence; >$1M rev or hosted service needs written auth.** Personal/client studio use — user decision recorded |
| Qwen-Image-2.1 base (`--image-edit`) | Qwen Research License | non-commercial |
| FLUX3-K | FLUX Kommunity | non-commercial; commercial use of outputs only <$5M revenue |
| MiniMax Music 3 | Community License | show "MiniMax-Music3" in UI; >$20M rev needs auth |
| YuE2 weights | CC BY-NC 4.0 + creator permission | individuals may sell songs; company needs licence |
| MMAudio | CC-BY-NC 4.0 | non-commercial |
| Stable Audio Open | Stability AI Community | gated, accepted |
| MOSS-Image | Apache-2.0 | — |
| Nemotron Bolt | OpenMDW 1.1 | commercial OK |
| Drama3 | fishaudio | ungated |

Non-commercial-restricted weights ship with `--all`: Qwen base, YuE2,
MMAudio, FLUX3-K. Flagged to user — acceptable for personal/client-studio
use, worth re-checking if outputs are ever sold commercially.

## Host-mutation note

Everything lands under `lk`'s home (`$PREFIX`, `~/.cache`, STUDIO_HOME) —
upstream's design: "nothing as root, no system file edited." Role needs
`become` only for apt deps and `loginctl enable-linger`.
