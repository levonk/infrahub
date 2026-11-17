# Imagination Studio — Alternatives

This is adoption of a **named project**, not a category selection — the user
picked Imagination Studio specifically (no competing AI-film-studio packages
evaluated). The real decision space was *topology*, evaluated below.

## Topology options compared

| Option | Verdict |
|---|---|
| **A. Head natively on kckinai, tailnet-only** ✅ | Chosen. Upstream's primary path; every job kind works (voice/music/chains/training are head-only + need GB10 engines). Nothing on Windows. |
| B. Head in container on dtop202311 (amd64) + kckinai worker | Rejected. User's original ask — feasible via the app's native worker model (ssh+rsync+tunnel; `SPARK_COMFY_URL` for pictures), but `KINDS=("video")` means voice/music/long-chains/`studio`/training still die on the GPU-less head. Partial-feature deployment. |
| C. Native Windows Studio on dtop202311 | Rejected. Upstream Windows support requires Windows 11 on Arm + RTX Spark N1X; dtop202311 is amd64 — unsupported. |
| D. Head on kckinai + second Studio UI for GPU-only kinds | Rejected as *primary* design (adds a second library/queue). Still available organically — any Spark registered as a worker runs a full Studio; open it for the rare head-only-kind needs if A were ever containerized. |

## Sub-decisions

| Question | Answer | Why |
|---|---|---|
| Containerize on kckinai? | No — native | Upstream ships no runtime image (`Dockerfile.ghcr` is a payload *carrier*); app spawns managed ComfyUI/engines/memguard expecting a real host. Matches `ai-comfyui` precedent: GB10 workloads are native. |
| Share models with existing ComfyUI (:8188)? | No — separate trees, disjoint families | Studio pins its own ComfyUI commit (H3/MOSS nodes) and manages its lifecycle (:8190). Optional later: `extra_model_paths.yaml` to let :8188 read Studio's tree. |
| Exposure via Traefik/`*.nl.levonk.com`? | No — tailnet only | `HOST=<tailscale IP>` bind + access key + `*.ts.net` trusted_host. Zero new DNS/attack surface. Traefik possible later via `STUDIO_ALLOWED_HOSTS`. |
| HF token in vault? | No — already on host | `~lk/.cache/huggingface/token` (account `Thren`) valid + gated access verified. Less secret movement beats vault injection. |
| `--all` vs selective? | `--all --h3-image` | User choice; 423 GB of 3.0 T free. `--h3-image` excluded from `--all`, asked for by name. |
