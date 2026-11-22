# ai-whisper-server

Deploys **whisper.cpp** (`whisper-server`) as a CUDA-enabled Docker container
on NVIDIA inference hosts (kckinai / GB10).

- Image built **on the target host** via `community.docker.docker_image`
  `source: build` (no aarch64 CUDA builder available elsewhere).
- GPU passthrough via `device_requests` capabilities `["gpu"]`.
- Models mounted read-only from `whisper_models_host_dir` (client overrides to
  reuse an existing cache, e.g. `/home/lk/models/whisper`).
- Silero VAD enabled by default to suppress hallucinations on silence.
- HTTP API: `POST /inference` (multipart `file`), consumed by the bffdwn
  `audio-pipeline` Mac orchestrator.

## Deploy

```bash
ansible-playbook \
  -i levonk/active/02-config/ansible/inventories/localnet.yml \
  shared/active/02-config/ansible/playbooks/deploy-whisper-server.yml \
  --vault-password-file ~/.ansible/vault_password \
  --limit kckinai
```
