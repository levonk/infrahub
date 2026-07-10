---
name: infrahub-container-deploy
description: Infrahub-specific overlay for deploying containerized services. Covers userns-remap UID 100000 bind mounts, vault secret handoff via ansible-vault, infrastructure variable naming (infra_ prefix), functional-group role naming, and local registry integration. Use when creating Ansible roles for container deployment in the infrahub project. Complements the general container-image-build and container-service-deploy skills. Do NOT trigger on general Ansible patterns (use the ansible skill) or image building (use container-image-build).
version: 1.0.0
date:
  created: "2026-07-09"
  updated: "2026-07-09"
  last-used: "2026-07-09"
tags:
  - "container"
  - "ansible"
  - "infrahub"
  - "deployment"
  - "devops"
triggers:
  - user
see-also:
  - skill: container-image-build
    relationship: complement
    description: "Builds the images this skill deploys"
  - skill: container-service-deploy
    relationship: complement
    description: "General deployment patterns (compose for dev, Ansible for prod)"
  - skill: ansible
    relationship: complement
    description: "General Ansible best practices for infrahub"
---

# Infrahub Container Deploy

Infrahub-specific overlay for deploying containerized services. This skill
COMPLEMENTS the general `container-service-deploy` skill (which covers
compose vs Ansible decision) and the `ansible` skill (which covers general
Ansible patterns). This skill covers the container-deployment-specific
overlay for the infrahub project.

## Deployment Workflow

1. **Build the image** using the `container-image-build` skill (check pre-built
   first, multi-arch mandatory, no Nix unless runtime needs it)
2. **Push to local registry** at the address defined in infra vars (never
   hardcoded)
3. **Create Ansible role** with functional-group prefix naming
4. **Deploy via playbook** using `community.docker.docker_container`

## Infrahub-Specific Constraints

### Userns-Remap (UID 100000)

Bind mounts use userns-remap UID 100000 (not 1000). All container tasks must
account for this — files on the host are owned by UID 100000, but inside the
container they appear as UID 0 (root) or the mapped user.

- When creating host directories for bind mounts, set ownership to 100000:100000
- When the container writes to bind-mounted volumes, files appear as 100000 on
  the host
- PUID/PGID env vars inside containers should be set appropriately for the
  userns-remap configuration

### Vault Handoff

The agent NEVER edits the vault directly. Instead:

1. The agent generates the `docker run` command with placeholder values for
   secrets
2. The user adds the actual secrets via `ansible-vault edit` on the
   appropriate vault file
3. The agent references vault variables in tasks with
   `{{ vault_variable_name | default('') }}`

Vault file location:
`shared/active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml`

Vault file naming: `group_name.vault.yml` (never `vault-group_name.yml` —
Ansible won't recognize it)

### Infrastructure Variables

All ports, IPs, and domains must be infrastructure variables in
`shared/active/02-config/ansible/infrastructure/` — never hardcoded in tasks
or roles.

Naming convention: `infra_{CATEGORY}_{SERVICE}_{CONTEXT}_{ATTRIBUTE}`

Examples:
- `infra_nix_cache_harmonia_host_port`
- `infra_nix_cache_ncps_container_port`
- `infra_nix_cache_attic_server_ip`

Infrastructure variable files:
- `ports.yml` — all port assignments
- `storage.yml` — storage paths and mount points
- `networks.yml` — network configurations, IPs, domains

### Role Naming

Roles use functional-group prefixes, not bare service names:

- `nix_cache_harmonia` (not `harmonia`)
- `nix_cache_ncps` (not `ncps`)
- `nix_cache_attic` (not `attic`)
- `nix_cache_ncro` (not `ncro`)

This groups related services together in the role directory and makes the
functional purpose clear.

### Inventory Integration

Reference inventories in:
`shared/active/02-config/ansible/inventories/`

Group vars and vault files live alongside the inventory. Use the appropriate
inventory group for the deployment target.

### Local Registry

The local registry address is defined in infrastructure variables (not
hardcoded). Images are pushed to the registry after building, then pulled by
Ansible during deployment using `community.docker.docker_image` with
`source: pull`.

## References

- `references/role-template.md` — template for a new container deployment role

## Cross-References

- **ADR**: `shared/active/08-docs/adr/adr-20260709001-container-build-strategy-mixed-arch.md`
- **General Ansible skill**: `.claude/skills/ansible/SKILL.md`
- **Published skills** (available after skills-src build + publish):
  - `container-image-build`: https://github.com/levonk/skills-releases/blob/main/skills/software-dev/container-image-build/SKILL.md
  - `container-service-deploy`: https://github.com/levonk/skills-releases/blob/main/skills/software-dev/container-service-deploy/SKILL.md
- **Published rule** (inlined into the above skills at build time):
  - `container-build-principles.md`: https://github.com/levonk/skills-releases/blob/main/rules/software-dev/devops/container-build-principles.md
