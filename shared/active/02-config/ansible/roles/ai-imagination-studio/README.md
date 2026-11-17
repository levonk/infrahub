# ai-imagination-studio — Imagination Studio (native on kckinai)

Deploys [Imagination Studio](https://github.com/Keys-Wasserman/Imagination-Studio-by-keys-Wasserman)
("TensorFold Studio" upstream) — an AI film studio (video/image/voice/music
generation on the GB10) — **natively** on kckinai as the `lk` user. Follows
the `ai-comfyui` precedent: native install, not a container, because the
GPU workloads need aarch64-CUDA and the app *is* the queue/worker head.

Upstream source: <https://github.com/Keys-Wasserman/Imagination-Studio-by-keys-Wasserman>
(pinned to tag `v4.5.0` via `ai_studio_ref`).

## What this role does

1. **validate** — asserts the `infra_storage_studio_*` / `infra_port_ai_studio_*`
   variables and resolves the run user's home/uid via `getent`.
2. **deps** — apt/dnf packages (`git`, `ffmpeg`, `python3`, `python3-venv`,
   `rsync`, `openssh-*`, `curl`, `ca-certificates`) and `uv` in
   `~lk/.local/bin` when missing (the oneshot installer also self-installs
   `uv`, but only finds it if `~/.local/bin` is already on `PATH`). Docker is
   verified present but never installed (DGX OS ships it).
3. **dirs** — `STUDIO_HOME`, install dir, `PREFIX`, HF cache dir and
   `~/.config/systemd/user`, all owned by `lk`.
4. **checkout** — `ansible.builtin.git` clone of the upstream repo at
   `ai_studio_ref` into `{{ infra_storage_studio_install_dir }}`.
5. **env** — resolves the bind address with `tailscale ip -4` on the host
   (same mechanism as `playbooks/bootstrap-ai-inference-host.yml`; override
   with `ai_studio_bind_host`), then templates the env file.
6. **service** — templates a **systemd --user** unit
   (`~lk/.config/systemd/user/imagination-studio.service`), runs
   `loginctl enable-linger lk`, then `systemctl --user enable --now` via
   `ansible.builtin.systemd` with `scope: user`.
7. **verify** — probes `http://<tailnet-ip>:7870/api/spark/self`. Accepts
   `200` (keyed) and `401` (alive, key required) — the probe never reads the
   access-key file. It self-skips until `$PREFIX/venv` exists, i.e. until the
   models playbook has built the environment.

## What this role does NOT do

- **No model/component install.** `oneshot-setup-spark.sh --all --h3-image`
  (~423 GB of weights, venv, ComfyUI, engines) runs from
  `playbooks/deploy-imagination-studio-models.yml` (story 04-001). Until then
  `scripts/app.sh` exits (`no environment at $PREFIX`) and the unit
  restart-loops harmlessly.
- **No memguard install.** The oneshot installer installs
  `scripts/memguard.py`'s per-user watchdog itself; keep the default (it must
  never run with `--memguard-stop-foreign`, or it could kill vLLM).
- **No Traefik / no firewall rules.** Tailnet-only by binding `HOST` to the
  tailscale IPv4; `*.ts.net` already passes upstream's `trusted_host()`.
- **No vault items.** HF auth already lives at `~lk/.cache/huggingface/token`
  on the host — the role never reads it.

## Key design decisions

- **Ref pin:** `ai_studio_ref: "v4.5.0"` — the newest upstream release tag
  (`git ls-remote --tags` → `v4.5.0` = `e7d7c6c`, VERSION file reads 4.5.0).
  Bump the var to upgrade the checkout; the models playbook re-runs the
  installer afterwards (`oneshot-setup.sh --upgrade` path).
- **Tailnet bind:** `HOST` is the output of `tailscale ip -4` on kckinai —
  resolved at converge time, not `ansible_host` (which is the LAN/tailnet
  SSH address, not guaranteed to be the tailnet IPv4 the app should bind).
  Binding the tailnet IP means the app is unreachable from the LAN even
  without the access key.
- **`HF_HOME` deliberately unset:** upstream honors `HF_HOME`
  (`app/bolt.py`, `app/discover.py`, `app/hf_gate.py`), but pointing it at
  `infra_storage_studio_hf_cache_dir` would hide the existing HF token and
  hub cache under `~lk/.cache/huggingface`. Model weights are fetched with
  `hf download --local-dir` into `$PREFIX`, not the hub cache, so the cache
  dir is created but not exported.
- **systemd --user, not a system unit:** upstream's own pattern
  (`memguard.py install`) is per-user units at
  `~/.config/systemd/user/` + `systemctl --user`; the app is designed to run
  as the unprivileged `lk` user with nothing as root. `loginctl enable-linger`
  keeps the user manager (and `/run/user/<uid>`) alive without login, which
  is also what lets `systemctl --user` work over non-login SSH.
- **`ansible.builtin.systemd` with `scope: user`:** used for
  daemon-reload/enable/start/stop. Each task sets
  `become_user: lk` and `environment: XDG_RUNTIME_DIR=/run/user/<uid>` —
  `systemctl --user` needs the user's bus, which only exists once linger is
  enabled (the role waits for `/run/user/<uid>` right after enabling it).
  Handlers use the same scope/env via the `ai_studio_xdg_runtime_dir` fact.
- **Env file location:** `{{ ai_studio_home }}/imagination-studio.env`,
  consumed via `EnvironmentFile=`. Contains `HOST`, `PORT`, `STUDIO_HOME`,
  `PREFIX` plus anything in `ai_studio_env_extra` (e.g.
  `STUDIO_TRUST_TAILNET`, `STUDIO_ALLOWED_HOSTS`, `IMAGE_MODEL`).

## Variables

See `defaults/main.yml`. Notable overrides:

| Variable | Default | Purpose |
|---|---|---|
| `ai_studio_ref` | `v4.5.0` | upstream tag/branch/SHA to check out |
| `ai_studio_bind_host` | `""` (auto) | pin the bind IP; empty = `tailscale ip -4` |
| `ai_studio_enabled` / `ai_studio_state` | `true` / `started` | service on/off |
| `ai_studio_env_extra` | `{}` | extra `KEY=VALUE` lines in the env file |
| `ai_studio_verify_health` | `true` | run the verify-tag probe |
| `ai_studio_run_user` | `localnet_kckinai_ansible_user` (`lk`) | service user |

## Deployment

```bash
ansible-playbook \
  -i levonk/active/02-config/ansible/inventories/localnet.yml \
  shared/active/02-config/ansible/playbooks/deploy-imagination-studio.yml \
  --limit kckinai
```

Then the model install (separate, long-running, ~423 GB):

```bash
ansible-playbook \
  -i levonk/active/02-config/ansible/inventories/localnet.yml \
  shared/active/02-config/ansible/playbooks/deploy-imagination-studio-models.yml \
  --limit kckinai
```

## Operate

```bash
# on kckinai, as lk
systemctl --user status imagination-studio
journalctl --user -u imagination-studio -f
bash scripts/studio-key.sh   # prints the access key + URLs (from the checkout)
python3 scripts/memguard.py status
```

The studio access key is auto-generated at
`{{ ai_studio_home }}/access-key` (mode 0600) on first start — retrieve it
with `studio-key.sh` or the Settings → Access key QR in the UI.

## Coexistence on kckinai

- Port `7870` (app, tailnet IP only) and managed ComfyUI `127.0.0.1:8190`
  are registered in `infrastructure/ports.yml`; the existing native ComfyUI
  on `:8188` is untouched.
- Model tree lives under `{{ ai_studio_prefix }}` — disjoint from the
  existing ComfyUI tree at `/opt/localnet/services/comfyui`.
- The memguard watchdog (installed by the oneshot) measures free unified
  memory and politely queues renders around vLLM/ComfyUI — it never stops
  foreign processes without `--memguard-stop-foreign`.
