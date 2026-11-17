---
story_id: "02-001"
story_title: "Shared + levonk infra vars, services.yml entry"
story_name: "infra-vars-catalog"
prd_name: "imagination-studio"
prd_file: "internal-docs/feature/todo/imagination-studio/feat-202611170854-imagination-studio.md"
phase: 2
parallel_id: 1
branch: "levonk/20261116-imagination-studio"
status: "done"
assignee: ""
reviewer: ""
dependencies: []
parallel_safe: true
modules: ["ansible-infra-vars", "services-catalog"]
priority: "MUST"
risk_level: "low"
tags: ["infra-vars", "ports", "storage", "services-catalog"]
due: "2026-11-17"
create-date: "2026-11-17"
update-date: "2026-11-17"
---

## Summary

Add all `infra_*` variables for Imagination Studio to the shared
infrastructure schema files plus the levonk client overrides, and add the
service catalog entry in `services.yml`. No role/playbook work — vars and
catalog only.

## Sub-Tasks

- [ ] `shared/active/02-config/ansible/infrastructure/ports.yml` — add
  `infra_port_ai_studio_host: "7870"` and
  `infra_port_ai_studio_container: "7870"` near the existing
  `infra_port_ai_comfyui_*` block (~line 755). Also register the managed
  ComfyUI port as loopback-only conflict-tracking vars:
  `infra_port_ai_studio_comfy_host: "8190"` /
  `infra_port_ai_studio_comfy_container: "8190"` with a comment that it is
  app-spawned on loopback and never published. Check 7870/8190 are unused
  elsewhere in ports.yml first (verified free 2026-11-16 — re-verify).
- [ ] `shared/active/02-config/ansible/infrastructure/storage.yml` — add
  `infra_storage_studio_base_dir:
  "{{ infra_storage_services_dir }}/imagination-studio"` (=/opt/localnet/
  services/imagination-studio), `infra_storage_studio_install_dir`,
  `infra_storage_studio_home_dir` (= base_dir, the STUDIO_HOME),
  `infra_storage_studio_prefix_dir` (install PREFIX for venv/models/
  ComfyUI — upstream convention `~/ImaginationStudio-studio` or per
  installer; pick a path under base_dir and document), and
  `infra_storage_studio_hf_cache_dir`. Follow the comfyui block
  (storage.yml:365-377) comment style.
- [ ] `levonk/active/02-config/ansible/infrastructure/ports.yml` +
  `storage.yml` — add client overrides ONLY where the client value
  differs from shared default; same values → no override needed (check
  existing comfyui precedent at levonk ports.yml:103-106 — it duplicates
  8188 explicitly; mirror that pattern for consistency).
- [ ] `shared/active/02-config/ansible/infrastructure/services.yml` — add
  catalog entry near the ComfyUI entry (~line 1853): name "Imagination
  Studio", container/hostname `imagination-studio`, machine `kckinai`,
  category `ai`, description (AI film studio — FastH3 video, Qwen/FLUX
  images, Drama3 voice, Music3/YuE2; tailnet-only), source_repo upstream
  URL, ports host 7870 (label "Web UI (tailnet)"), traefik: false,
  health_endpoint `/api/spark/self`, pipeline "none", alert_labels
  matching comfyui style. Domains list — use tailnet FQDN
  `infra_tailscale_fqdn_inference_host` if the services schema supports
  it, else omit/empty with a note.
- [ ] Regenerate service catalogs if the repo has a generator
  (SERVICES.md is generated — find the generator script/just recipe;
  `grep -rn "SERVICES.md" justfile scripts/`). Do NOT hand-edit
  generated files.
- [ ] Verify: `devbox run -- rtk ansible-playbook --syntax-check` is N/A
  (no playbook); run the catalog generator + `git diff` review; grep for
  port conflicts.

## Acceptance Criteria

- All new vars follow `infra_{CATEGORY}_{SERVICE}_{CONTEXT}_{ATTRIBUTE}`
  naming; zero hardcoded ports/IPs outside variable definitions.
- `services.yml` entry validates against existing schema (same keys as
  comfyui entry).
- Catalogs regenerated and committed.
- ansible-lint unaffected (vars files only).
