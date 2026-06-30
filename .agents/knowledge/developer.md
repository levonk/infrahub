# Developer Guide: infrahub

This guide is for developers/agents working on the infrahub codebase. For user-facing setup and project overview, see the root [`AGENTS.md`](../../AGENTS.md).

## JIT Index
- Out of Scope: Not yet established — check `internal-docs/` for ADRs and architecture docs before adding features
- Root AGENTS.md: [`../../AGENTS.md`](../../AGENTS.md) — environment setup, vault, deployment workflow, architectural invariants
- Add New Service Workflow: [`../workflows/infrahub-add-new-service.md`](../workflows/infrahub-add-new-service.md) — 10-phase checklist for adding a new service end-to-end (shared schemas → client values → vault → role → Traefik → dashboard → deploy → verify)

## <commands>
**Devbox Commands (Environment)**
- `devbox run -- just <target>` — Run a justfile target in the devbox environment
- `devbox run -- ansible-playbook ...` — Run Ansible playbooks
- `devbox run -- just ansible-lint-internal` — Lint all Ansible roles/playbooks

**Build & Push (Docker Images)**
- `devbox run -- just docker-build-push-all` — Build + push all locally-built images (skips unchanged via context hash)
- `devbox run -- just docker-build-push-all-force` — Force rebuild all (ignores cache)
- `devbox run -- just docker-build-push <image>` — Build + push a single image (e.g., `headroom`)
- `devbox run -- just docker-build-list` — List all images that can be built

**Deployment**
- `devbox run -- ansible-playbook -i <inventory> <playbook> --vault-password-file ~/.ansible/vault_password`
- See AGENTS.md "Deployment Workflow Rule" section for the full 4-path workflow
</commands>

## <workflow>
1. Enter project directory: `cd /Users/micro/p/gh/levonk/infrahub`
2. Activate environment: `export PATH="/nix/var/nix/profiles/default/bin:$HOME/.local/share/devbox/global/shims:$PATH"`
3. Lint: `devbox run -- just ansible-lint-internal`
4. Make changes to roles/playbooks/templates
5. Deploy locally or remotely per the AGENTS.md workflow
6. Verify: check container health, logs, and service endpoints
7. Commit with conventional commit message
</workflow>

## <key-directories>
- `shared/active/02-config/ansible/roles/` — All reusable Ansible roles (functional-group prefixes)
- `shared/active/02-config/ansible/playbooks/` — Stack blueprints that import roles
- `shared/active/02-config/ansible/infrastructure/` — Shared infrastructure schemas (neutral defaults only)
- `shared/active/03-container/services/` — Docker compose reference files + Dockerfiles for locally-built images
- `levonk/active/02-config/ansible/` — Client-specific inventories, host_vars, group_vars, infrastructure values, vault
- `scripts/` — Build/deploy helper scripts (wrapped by justfile targets)
- `shared/active/08-docs/adr/` — Architecture Decision Records
</key-directories>

## <key-files>

### Critical Files — Do Not Replicate or Duplicate

These files are the **single source of truth** for their domain. Never create parallel definitions, never copy values into roles/playbooks/group_vars, never hardcode the values they define.

```text
infrahub/
├── AGENTS.md                                    # Root agent guidelines — environment, vault, deployment, invariants
├── justfile                                     # All developer commands (wraps scripts/, delegates to devbox)
├── scripts/
│   └── build-and-push-images.sh                 # Build + push all locally-built images to registry (caching via context hash)
│
├── shared/active/02-config/ansible/
│   ├── ansible.cfg                              # Ansible configuration (collections_paths, roles_path, etc.)
│   ├── infrastructure/                          # SHARED SCHEMAS — neutral defaults only, no client values
│   │   ├── domains.yml                          #   Domain name schema
│   │   ├── networks.yml                         #   Network topology schema
│   │   ├── ports.yml                            #   Port allocation schema
│   │   ├── storage.yml                          #   Storage path schema
│   │   └── apps.yml                             #   Application registry schema
│   ├── roles/                                   # All reusable roles (NEVER put client data here)
│   └── playbooks/                               # All stack blueprints
│
├── levonk/active/02-config/ansible/             # CLIENT-SPECIFIC — the actual values
│   ├── inventories/
│   │   ├── oci.yml                              # OCI cloud server inventory
│   │   ├── localnet.yml                         # Local network inventory
│   │   ├── group_vars/
│   │   │   ├── all.yml                          # Common vars (non-secret)
│   │   │   ├── cloud_servers.yml                # Cloud server group vars
│   │   │   ├── infrahub-levonk-all.vault.yml    # 🔒 VAULT — ALL secrets (API keys, tokens, passwords)
│   │   │   └── ...
│   │   └── host_vars/
│   │       └── oci-cloud-server.yml             # Per-host overrides (highest precedence)
│   └── infrastructure/                          # CLIENT VALUES — the single source of truth
│       ├── domains.yml                          #   Actual domain names, DNS records, hostnames
│       ├── networks.yml                         #   Actual subnets, gateways, IP allocations
│       ├── ports.yml                            #   Actual port allocations (host/container by service)
│       └── storage.yml                          #   Actual storage paths, volumes, mounts
│
└── shared/active/03-container/services/         # Dockerfiles for locally-built images
    ├── agentmemory/docker/Dockerfile.agentmemory
    ├── ai-services/omniroute/docker/Dockerfile.omniroute
    ├── ai-codeassist/headroom/Dockerfile.headroom
    ├── dns/adguard/Dockerfile.adguard
    ├── dns/coredns/docker/Dockerfile.coredns
    ├── dns/dnscrypt/docker/Dockerfile.dnscrypt-proxy
    ├── dns/dnsdist/docker/Dockerfile.dnsdist
    ├── dns/dns-blocklists/Dockerfile.blocklist-compiler
    ├── proxy/tor/docker/Dockerfile.tor
    ├── proxy/9router/Dockerfile
    └── base/                                    # Base images (alpine, kali, kalinix, hermes-agent, nix-sidecar)
```

### External Critical Files (Not in Repo)

```text
~/.ansible/vault_password                        # 🔒 Vault decryption key — required for all deployments
~/.docker/daemon.json                            # Docker daemon config (insecure-registries for local registry)
~/.ssh/lzkmbp2016-micro-oracle                   # SSH key for OCI cloud server access
```

### Configuration Files (Modify with Care)

| File | Purpose | Risk |
|------|---------|------|
| `levonk/.../infrastructure/networks.yml` | All IP subnets, allocations | Changing IPs breaks running containers |
| `levonk/.../infrastructure/ports.yml` | All port assignments | Changing ports breaks Traefik routing |
| `levonk/.../infrastructure/domains.yml` | All domain names | Changing domains breaks DNS + certs |
| `levonk/.../infrastructure/storage.yml` | All storage paths | Changing paths loses data |
| `levonk/.../inventories/group_vars/infrahub-levonk-all.vault.yml` | All secrets | 🔒 Never commit plaintext, never share values |
| `shared/.../roles/proxy-traefik/templates/traefik.yml.j2` | Traefik static config | Wrong ACME config = self-signed certs |
| `shared/.../roles/proxy-traefik/templates/dynamic/*.yml.j2` | Traefik dynamic configs | Wrong routing = 404s |
| `~/.docker/daemon.json` | Docker insecure registries | Missing entry = registry push/pull fails |

</key-files>

## <patterns>

### ✅ DO
- Reference infrastructure variables: `{{ infra_port_worldmonitor_host }}`, `{{ infra_domain_worldmonitor_web }}`
- Use `{{ local_registry | default('100.90.22.85:5000') }}` prefix for locally-built images
- Use `source: pull` for all `docker_image` tasks (Invariant #2: build on Mac, pull on target)
- Put client-specific values in `levonk/active/02-config/ansible/infrastructure/*.yml`
- Put secrets in the vault file only
- Use functional-group prefixes for role names (`dns-`, `proxy-`, `vpn-`, `ai-`)

### ❌ DON'T
- Hardcode IPs, ports, domains, or storage paths in roles/playbooks/templates
- Put client-specific values in `shared/` roles or defaults
- Use `source: build` in `docker_image` tasks (violates Invariant #2)
- Put secrets in plaintext files, group_vars, or host_vars (use the vault)
- Duplicate infrastructure values across files (single source of truth)
- Create new infrastructure variable files — use the existing 4 (`domains`, `networks`, `ports`, `storage`)

</patterns>

## <boundaries>

### <always>
- Use `devbox run --` prefix for all commands (fresh shell)
- Use `--vault-password-file ~/.ansible/vault_password` for all Ansible deployments
- Reference infrastructure variables, never hardcode values
- Run `ansible-lint` before committing role/playbook changes
- Verify container health after deployment (`docker ps`, `docker logs`)
- Check Traefik logs for ACME errors after cert-related changes
- Build images for `linux/arm64` (OCI server is aarch64)
- Push to local registry before deploying roles that use `source: pull`

### <ask-first>
- Changing any file in `levonk/.../infrastructure/` (breaks running services)
- Modifying the vault file (secrets are sensitive)
- Changing Traefik static config (`traefik.yml.j2`) — can break all routing
- Changing ACME/cert resolver config — can cause cert failures
- Adding new playbooks (check existing ones first)
- Removing any role (check for dependencies first)
- Changing Docker network subnets (requires container recreation)

### <never>
- Commit secrets or credentials in plaintext
- Put client-specific values in `shared/` directory
- Use `source: build` in `docker_image` tasks on target hosts
- Use `docker compose` for deployments (use `community.docker` modules only)
- Hardcode IPs, ports, domains, or storage paths
- Delete or modify `~/.ansible/vault_password`
- Edit the vault file directly (use the `docker run` ansible-vault edit command from AGENTS.md)
- Replicate infrastructure values outside the 4 centralized files
- Create parallel definitions of services, ports, or domains in group_vars/host_vars

</boundaries>

## <known-gotchas>

- **Disk space on OCI server**: The physical disk is 200G but the root LV was originally only 30G. Run `sudo xfs_growfs /` to grow XFS to fill the LV, and `sudo lvextend -l +100%FREE /dev/ocivolume/root && sudo xfs_growfs /` to use all VG space. After both, the root filesystem is 183G. If disk fills again, clean with `docker system prune -af`.
- **`localnet_network_subnet` undefined**: A pre-existing error in the `common` role when running certain playbooks. Non-blocking — roles that need networks define their own. Do not try to fix this by adding the variable; the roles work around it.
- **Traefik Docker provider disabled**: Traefik v3.0 has an API incompatibility with the Docker provider. All routing is via file-provider dynamic configs in `/opt/traefik/config/dynamic/`. Do NOT re-enable the Docker provider or add traefik.* labels to containers.
- **ACME staging vs production**: Check `caServer` in the Traefik static config. Staging certs have `(STAGING)` in the issuer CN. If staging certs are cached in `acme.json`, delete them and restart Traefik to get production certs.
- **Build caching**: `build-and-push-images.sh` uses a context-hash label (`ctxhash`) to skip unchanged images. Use `--force` or `FORCE_REBUILD=1` to override. The hash is computed from all files in the build context directory.
- **Multi-platform images**: `docker save` includes all platforms. When transferring images via `docker save | docker load`, build with `--platform linux/arm64` first to avoid saving x86_64 layers that waste disk on the target.
- **Healthcheck durations**: `community.docker.docker_container` rejects bare integers for healthcheck intervals. Use strings with unit suffixes (`"30s"`, `"5s"`).
- **Handler `state: restarted`**: Not valid in current `community.docker` version. Use `state: started` with `restart: true`.
- **envoy/privoxy/squid**: These services use upstream Docker Hub images directly (no custom Dockerfiles). Do NOT try to build them locally.
- **TraLa exclude patterns**: Use router names WITHOUT the `@file` suffix (e.g., `trala-https`, not `trala-https@file`). Wildcards: `*` matches any chars, `?` matches one char.

</known-gotchas>

## Definition of Done
- [ ] Ansible lint passes: `devbox run -- just ansible-lint-internal`
- [ ] Deployment succeeds without fatal errors
- [ ] Container(s) running and healthy: `docker ps`, `docker logs <container>`
- [ ] No secrets or credentials in plaintext
- [ ] Infrastructure values referenced, not hardcoded
- [ ] Conventional commit message used
- [ ] Affected AGENTS.md files updated per Maintenance Protocol
- [ ] If cert/Traefik changes: verify Let's Encrypt issuer (not staging, not TRAEFIK DEFAULT CERT)
- [ ] If TraLa changes: verify `/api/services` endpoint shows correct services with icons
