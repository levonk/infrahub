# ai-comfyui — ComfyUI Image/Video Generation Pipeline

Deploy ComfyUI natively on the GB10 inference host (kckinai) for image/video
generation using Wan 2.2 14B I2V + character LoRA + keyframe workflows.

## Architecture

ComfyUI runs **natively** (not Docker) on the GB10. This role provisions:

- Storage directories (models, LoRAs, output, input, custom nodes, config)
- Systemd service (`comfyui.service`)
- Firewall rules (ufw / firewalld)

The actual ComfyUI installation (Python venv, pip install, custom nodes,
model downloads) is handled by the
[levonk-ai-playground](https://github.com/levonk/levonk-ai-playground) repo's
install scripts. This role assumes ComfyUI is installed at
`{{ comfyui_install_dir }}` with a Python venv at `{{ comfyui_venv_dir }}`.

## Pipeline

- **Keyframe generation**: SDXL / Flux for clean reference images
- **Character identity**: LoRA + reference image conditioning (IP-Adapter)
- **Motion**: Wan 2.2 14B I2V for animating keyframes
- **Upscaling**: Real-ESRGAN / SeedVR
- **Smoothness**: RIFE frame interpolation
- **Encoding**: ffmpeg H.264/H.265

## Variables

All variables reference the `infra_*` infrastructure variables. See
`defaults/main.yml` for the full list.

## Deployment

```bash
ansible-playbook \
  -i levonk/active/02-config/ansible/inventories/localnet.yml \
  shared/active/02-config/ansible/playbooks/deploy-comfyui.yml \
  --vault-password-file ~/.ansible/vault_password \
  --limit kckinai
```

## Traefik Routing

ComfyUI's web UI is exposed via Traefik on the OCI cloud server with
cross-machine routing to kckinai's Tailscale FQDN. The Traefik dynamic
config template (`comfyui.yml.j2`) is deployed by the `proxy-traefik` role
when `comfyui_enabled` is true.

## Backup

Model checkpoints and LoRAs are large and can be re-downloaded — they are
not backed up by default. Output videos and reference image packs should
be backed up manually or via rsync to `/opt/localnet/backup/comfyui/`.
