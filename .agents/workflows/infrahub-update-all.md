---
workflow: "Update All Services Across All Infrahub Clients"
slug: "infrahub-update-all"
description: "Audit all running Docker containers across all active infrahub clients, compare against latest available image releases (>=2 days old, nothing younger), update pinned Ansible variables, pull latest images, run playbooks to recreate containers, and verify health. Covers the full audit-to-verification lifecycle including pre-existing issue detection and handoff generation."
use: "When the user asks to update all services, audit running containers, check for outdated images, or perform a fleet-wide version refresh across infrahub clients. Also use after adding new services to ensure the fleet is current, or as a periodic maintenance task."
date:
  created: "2026-07-20"
  updated: "2026-07-23"
  last-used: "2026-07-23"
see-also:
  - skill: "ansible"
    relationship: "implementation"
    description: "Best practices for Ansible automation in infrahub — community.docker modules, variable validation, vault integration. Used in Phase 3 (deploy) for all playbook executions."
  - skill: "git-repository-management"
    relationship: "implementation"
    description: "Commit workflow for the pinned version variable changes across the infrahub parent repo and client submodules. Used in Phase 5 (commit)."
  - skill: "handoff"
    relationship: "documentation"
    description: "Capture session context for continuation. Used in Phase 6 when the audit surfaces pre-existing issues that need follow-up in a future session."
  - file: "infrahub-git.md"
    relationship: "sibling"
    description: "Git repository management workflow for infrahub and all client submodules. Run after this workflow to commit the pinned version changes."
  - file: "infrahub-add-new-service-orchestrator.md"
    relationship: "sibling"
    description: "Workflow for adding new services. Run this update workflow after adding new services to ensure the fleet is current."
---

# Workflow: Update All Services Across All Infrahub Clients

Audit all running Docker containers across all active infrahub clients, compare
against the latest available image releases, update pinned Ansible variables,
deploy via playbooks, and verify health.

## Prerequisites

1. Read the root [`AGENTS.md`](../../AGENTS.md) — especially "Architectural
   Invariants", "Per-Client Centralized Files", devbox usage rules, and vault
   handoff policy.
2. Read [`shared/active/02-config/ansible/AGENTS.md`](../../shared/active/02-config/ansible/AGENTS.md)
   — container module rules, port conflict checking.
3. Read [`levonk/AGENTS.md`](../../levonk/AGENTS.md) — submodule workflow, secret
   storage rules.
4. All shell interaction with tools (ansible, docker, etc.) MUST use:
   `cd ~/p/gh/levonk/infrahub && devbox run -- <command>`
5. Vault password file: `~/.ansible/vault_password`
6. SSH key for OCI server: `~/.ssh/lzkmbp2016-micro-oracle`

## Policy: Release Age Filter

**All image updates must target releases that are at least 2 days old.** Nothing
younger. This avoids pulling brand-new releases that may be yanked or have
undiscovered issues. Calculate the cutoff date as `today - 2 days` and reject
any image whose tag was published after that date.

## Policy: Git Checkpoint and Rollback Tags

**Every run of this workflow MUST create pre-update and post-update git tags**
in both the `infrahub` parent repo and the `levonk` submodule, so that the
Ansible variable changes can be rolled back if a deployment goes wrong.

- **Pre-update tag**: Created in Phase 0, BEFORE any Ansible variables are
  edited or playbooks are run. This is the rollback point.
- **Post-update tag**: Created in Phase 5, AFTER all updates are deployed,
  verified, and committed. This marks the known-good state.

The `git-repository-management` skill auto-creates `tags/auto/YYYY/MM/...-{slug}-pre`
and `-post` tags on every `git-commit-batch.sh` run. This workflow relies on
that mechanism but also creates explicit `tags/updates/YYYY/MM/DD/service-update`
tags for human-readable rollback points.

**Rollback procedure**: If a deployment fails or containers are unhealthy after
update, roll back to the pre-update tag:

```bash
# In the levonk submodule
cd levonk && git tag -l "tags/updates/*" | tail -5  # find the pre-update tag
# Roll back (creates a backup branch first)
~/p/gh/levonk/skills-src/build/current/skills/software-dev/git-repository-management/scripts/git-rollback.sh \
  --to <pre-update-tag> --slug service-update-rollback levonk/

# In the infrahub parent
~/p/gh/levonk/skills-src/build/current/skills/software-dev/git-repository-management/scripts/git-rollback.sh \
  --to <pre-update-tag> --slug service-update-rollback
```

Then re-run the affected playbooks to recreate containers with the old images.

## Policy: Secret Redaction

**No secret values may appear in any output, audit report, handoff document, or
commit message produced by this workflow.** This includes values read from
`docker inspect`, container env vars, vault contents, playbook output, or logs.

### Why this exists

During the 2026-07-23 audit, an agent ran `docker inspect` on the NordVPN
container to capture its config for manual recreation, then wrote the captured
`OPENVPN_USER` and `OPENVPN_PASSWORD` values verbatim into the handoff
document. The credentials were never committed (caught by the git workflow's
secret scan), but they sat in plaintext on disk and in the conversation until
redacted. The root cause was an empty vault entry that forced a manual
`docker run` with plaintext env vars — but the proximate cause was the agent
copying secret values from `docker inspect` output into a doc instead of
referencing them by name.

### Rules

1. **Never copy secret values from `docker inspect` output.** When documenting
   a container's config, reference env var *names* only (e.g.,
   `OPENVPN_USER=<redacted>`, `vault_nordvpn_openvpn_user` is empty). The
   values are needed for `docker run` recreation, but they must not be written
   into any file.
2. **Filter secret env vars before capturing config.** When running
   `docker inspect` for manual recreation (Phase 3e), exclude env vars whose
   names match `PASSWORD|PASS|SECRET|TOKEN|KEY|CREDENTIAL|AUTH` from any
   recorded output. Keep them only in the transient shell command used for
   `docker run` — never in a file.
3. **Scan handoff documents before writing.** Phase 6 must run a secret scan
   on the handoff content before saving the file. If any secret patterns are
   detected, redact them or abort.
4. **Scan staged files before committing.** Phase 5 must run a secret scan on
   `git diff --cached` before the commit batch executes. The
   `git-repository-management` skill already does this, but this workflow
   explicitly relies on it as the last line of defense.

### Secret patterns to scan for

```bash
# Minimal grep-based scan (use trufflehog/gitleaks if available for deeper detection)
rg -nE 'AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|sk-[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]+|AIza[0-9A-Za-z_-]{35}|-----BEGIN|://[^:]+:[^@]+@|[A-Z_]*(PASSWORD|PASS|SECRET|TOKEN|KEY)[A-Z_]*=[^\s]{8,}' \
  --glob '!*.vault.yml' --glob '!*.lock'
```

## Phase 0: Pre-Update Git Checkpoint

**Before any Ansible variables are edited or playbooks are run**, ensure the
repository is in a clean state and create a pre-update rollback tag.

### 0a. Check Repository Cleanliness

Check both the `infrahub` parent repo and the `levonk` submodule for uncommitted
changes:

```bash
cd ~/p/gh/levonk/infrahub

echo "=== Parent repo status ==="
git status --porcelain

echo "=== Levonk submodule status ==="
cd levonk && git status --porcelain && cd ..
```

### 0b. Handle Dirty Repositories

If either repo has uncommitted changes, **do NOT proceed with the update**.
Choose one of:

1. **Ask the user to commit or stash first** (recommended):
   ```
   The levonk submodule has uncommitted changes:
   <list of changed files>
   
   Commit or stash these changes before running the update workflow.
   The workflow needs a clean repo to create a reliable rollback tag.
   ```
   Wait for the user to confirm, then re-check cleanliness.

2. **Commit the existing changes as a checkpoint** (only if the user explicitly
   approves):
   ```bash
   cd levonk && git add -A && git commit -m "checkpoint: pre-update cleanup" \
     -m "- Pre-update checkpoint before service update workflow"
   cd ..
   ```
   This uses the pre-task commit checkpoint protocol from the
   `git-repository-management` skill.

3. **Abort the workflow** if the user doesn't want to commit or stash:
   ```
   Cannot proceed: repository has uncommitted changes and user declined to
   commit or stash. Clean the repo and re-run the workflow.
   ```

**Why this matters**: If the repo is dirty when we start editing Ansible
variables, our changes get mixed with the user's existing changes. The pre-
update tag would capture both, and rolling back would lose the user's work
too. A clean repo ensures the pre-update tag marks exactly the state before
our changes.

### 0c. Create Pre-Update Tag

Once both repos are clean, create the pre-update tag in each:

```bash
cd ~/p/gh/levonk/infrahub

# Tag the levonk submodule
cd levonk
PRE_TAG="tags/updates/$(date -u +%Y/%m/%d)/service-update-pre"
git tag -a "$PRE_TAG" -m "Pre-update checkpoint: service update workflow"
echo "Levonk pre-update tag: $PRE_TAG"
cd ..

# Tag the infrahub parent
PRE_TAG="tags/updates/$(date -u +%Y/%m/%d)/service-update-pre"
git tag -a "$PRE_TAG" -m "Pre-update checkpoint: service update workflow"
echo "Infrahub pre-update tag: $PRE_TAG"
```

**Record both tag names** for use in Phase 5 (post-update tag) and for rollback
if needed.

## Phase 1: Enumerate Running Containers

`[fork]` For each active client, enumerate all running containers and their
image details from the target server(s).

### 1a. Identify Active Clients

Scan the infrahub inventory to find all active clients and their target hosts:

```bash
cd ~/p/gh/levonk/infrahub
# List inventory hosts
devbox run -- ansible-inventory \
  -i levonk/active/02-config/ansible/inventories/oci.yml \
  --list-hosts 2>/dev/null
```

### 1b. Enumerate Containers Per Host

For each host, SSH in and list all running containers with their images and
creation dates:

```bash
ssh -i ~/.ssh/lzkmbp2016-micro-oracle \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  opc@<HOST_IP> \
  "docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.CreatedAt}}' | sort"
```

**Capture for each container**: name, image (registry/repo:tag), status, created
date, and the image's digest (`docker inspect <name> --format '{{.Image}}'`).

### 1c. Identify Image Categories

Classify each running image into one of:

| Category | Example | Update Method |
|----------|---------|---------------|
| **Pinned upstream** | `traefik:v3.0`, `authelia/authelia:4.38` | Update Ansible variable, run playbook |
| **Floating upstream** | `postgres:16-alpine`, `qmcgaw/gluetun:latest` | Pull latest, run playbook or recreate |
| **Local build** | `100.90.22.85:5000/localnet-agentmemory:latest` | Rebuild from source, push to registry |
| **Local registry** | `100.90.22.85:5000/headroom:latest` | Rebuild from source, push to registry |

**Skip local builds** in this workflow — they require the build pipeline, not
image pulls. Note them in the audit report for follow-up.

## Phase 2: Compare Against Latest Available

`[fork]` For each upstream image, query the registry API to find the latest
available tag and its creation date.

### 2a. Docker Hub Images

Query the Docker Hub API for tags and their last-pushed dates:

```bash
# Get tags for a Docker Hub image (e.g., traefik)
curl -s "https://hub.docker.com/v2/repositories/library/traefik/tags/?page_size=25&ordering=last_updated" \
  | jq -r '.results[] | "\(.name)\t\(.last_updated)\t\(.digest // "no-digest")"' \
  | head -20
```

For non-library images (e.g., `authelia/authelia`):

```bash
curl -s "https://hub.docker.com/v2/repositories/authelia/authelia/tags/?page_size=25&ordering=last_updated" \
  | jq -r '.results[] | "\(.name)\t\(.last_updated)\t\(.digest // "no-digest")"' \
  | head -20
```

### 2b. GitHub Container Registry (GHCR) Images

Query the GitHub Packages API for GHCR images (e.g.,
`ghcr.io/berriai/litellm`):

```bash
# List packages for a GHCR image
curl -s "https://api.github.com/orgs/berriai/packages?package_type=container" \
  | jq -r '.[].name'
# Then get versions for a specific package
curl -s "https://api.github.com/orgs/berriai/packages/container/litellm/versions?per_page=10" \
  | jq -r '.[] | "\(.metadata.container.tags[0] // "untagged")\t\(.created_at)"'
```

For user-owned GHCR packages, replace `orgs/<org>` with `users/<user>`.

### 2c. cgr.dev (Chainguard) Images

Query the cgr.dev catalog:

```bash
curl -s "https://cgr.dev/v2/<image>/tags/list" \
  | jq -r '.tags[]' | sort -V | tail -10
```

### 2d. Compare Digests

For each running image, compare its digest with the latest available tag's
digest. If they match, the service is up to date. If they differ, the service
needs an update.

```bash
# Get running image digest
ssh -i ~/.ssh/lzkmbp2016-micro-oracle ... \
  "docker inspect <container> --format '{{.Image}}'"
# Get remote image digest
docker manifest inspect <registry>/<repo>:<tag> 2>/dev/null | jq -r '.manifests[0].digest'
```

### 2e. Apply Age Filter

For each image that needs an update, check the latest tag's publication date.
**Reject any tag published less than 2 days ago.** Record the age in the audit
report.

### 2f. Generate Audit Report

Categorize all services into:

1. **Up to date** — running digest matches latest available
2. **Needs update (latest >=2 days old)** — update now
3. **Needs update (latest <2 days old)** — hold back, record for follow-up
4. **Local build** — skip, note for build pipeline follow-up

Present the report to the user and ask for confirmation before proceeding to
Phase 3.

## Phase 3: Update Pinned Variables and Deploy

For each service that needs an update, update the Ansible configuration and
deploy.

### 3a. Find Pinned Version Variables

Search for the image tag/version variable in the Ansible configuration:

```bash
cd ~/p/gh/levonk/infrahub
# Search for the image name or tag in group_vars, host_vars, and defaults
grep -rn "<image_name>\|<image_tag>" \
  levonk/active/02-config/ansible/ \
  shared/active/02-config/ansible/roles/*/defaults/ \
  shared/active/02-config/ansible/playbooks/ 2>/dev/null
```

Common locations:

| Service | Variable File | Variable |
|---------|--------------|----------|
| traefik | `levonk/.../group_vars/cloud_servers.yml` | `proxy_traefik_image_tag` |
| authelia | `levonk/.../host_vars/oci-cloud-server.yml` | `proxy_authelia_version` |
| registry | `shared/.../playbooks/deploy-local-registry.yml` | `image:` (inline) |
| postgres | Role defaults or playbook inline | `image:` (inline) |

### 3b. Update Pinned Variables

Edit the variable to the new version. Use the `edit` tool for exact string
replacement.

**For pinned version variables** (e.g., `proxy_traefik_image_tag: "v3.0"`):

```yaml
# Before
proxy_traefik_image_tag: "v3.0"
# After
proxy_traefik_image_tag: "v3.7.8"
```

**For inline image references** in playbooks (e.g.,
`image: "docker.io/registry:2"`):

```yaml
# Before
image: "docker.io/registry:2"
# After
image: "docker.io/registry:3.1.1"
```

### 3c. Pull Latest Images

Pre-pull all updated images on the target server before running playbooks. This
avoids timeouts during container recreation:

```bash
ssh -i ~/.ssh/lzkmbp2016-micro-oracle ... \
  "docker pull <registry>/<repo>:<new_tag>"
```

Pull all images in a single SSH session to minimize connection overhead.

### 3d. Run Ansible Playbooks

Run the appropriate playbook for each service. Use tags to target specific
services and avoid touching unrelated containers.

**Common playbooks and their tag patterns**:

| Playbook | Services | Tags |
|----------|----------|------|
| `cloud-server-infra.yml` | traefik, iron-proxy, authelia, postgres | `traefik,iron-proxy,authelia,always` |
| `cloud-server-vpn.yml` | tailscale, nordvpn | `tailscale,always` |
| `cloud-server-nordvpn.yml` | nordvpn/gluetun | `deploy,nordvpn,always` |
| `deploy-local-registry.yml` | local-registry | `deploy` |
| `deploy-omnigent.yml` | omnigent, omnigent-postgres | `deploy` |
| `deploy-ai-gateway-pipeline.yml` | litellm, litellm-postgres | (use `--skip-tags langfuse` to avoid langfuse stack) |
| `deploy-langfuse.yml` | langfuse-web, langfuse-worker, langfuse-postgres | `deploy` |

**Playbooks that load infrastructure vars in pre_tasks** (no extra `-e` needed):

- `cloud-server-infra.yml`
- `deploy-omnigent.yml`
- `deploy-ai-gateway-pipeline.yml`
- `deploy-local-registry.yml`

**Playbooks that do NOT load infrastructure vars** (require `-e @` for each
infrastructure file):

- `cloud-server-vpn.yml`
- `cloud-server-nordvpn.yml`

**Command pattern for playbooks that need infrastructure vars**:

```bash
cd ~/p/gh/levonk/infrahub
devbox run -- ansible-playbook \
  -i levonk/active/02-config/ansible/inventories/oci.yml \
  shared/active/02-config/ansible/playbooks/<playbook>.yml \
  --vault-password-file ~/.ansible/vault_password \
  -e @shared/active/02-config/ansible/infrastructure/ports.yml \
  -e @shared/active/02-config/ansible/infrastructure/networks.yml \
  -e @shared/active/02-config/ansible/infrastructure/domains.yml \
  -e @shared/active/02-config/ansible/infrastructure/storage.yml \
  -e @levonk/active/02-config/ansible/infrastructure/ports.yml \
  -e @levonk/active/02-config/ansible/infrastructure/networks.yml \
  -e @levonk/active/02-config/ansible/infrastructure/domains.yml \
  -e @levonk/active/02-config/ansible/infrastructure/storage.yml \
  --tags "<tags>,always"
```

**Command pattern for playbooks that load their own infrastructure vars**:

```bash
cd ~/p/gh/gh/levonk/infrahub
devbox run -- ansible-playbook \
  -i levonk/active/02-config/ansible/inventories/oci.yml \
  shared/active/02-config/ansible/playbooks/<playbook>.yml \
  --vault-password-file ~/.ansible/vault_password \
  --tags "<tags>"
```

### 3e. Handle Playbook Failures

Some playbooks may fail due to **pre-existing issues** (not caused by the
update). Common failure modes observed in practice:

| Failure | Cause | Workaround |
|---------|-------|------------|
| Vault validation fails (empty credentials) | Vault has empty strings for required secrets (e.g., `vault_nordvpn_openvpn_user`) | Recreate container manually with `docker run` using existing env vars. Note the vault issue for follow-up. |
| Missing local image (e.g., `localnet-proxy-tor:latest`) | A locally-built image doesn't exist on the server | Skip the failing task with `--start-at-task` to continue past it. Note the missing image for follow-up. |
| Custom command incompatible with new image entrypoint | New image version uses a different entrypoint (e.g., tailscale `containerboot`) | Recreate container manually without the custom command, relying on env vars instead. Note the role issue for follow-up. |
| Post-deployment config push fails | Non-critical post-deployment task (e.g., OmniRoute config push) | The container itself is healthy. Note the failure for follow-up. |

**For manual container recreation** (when playbooks are blocked):

1. Inspect the existing container to get its config. **Capture env var names
   only — never record secret values in any file.** Run two separate
   `docker inspect` calls: one for the non-sensitive config (safe to record),
   and one for the env vars (used only to construct the `docker run` command,
   never written to a file):

   **Safe to record** (network, ports, restart policy, caps, devices, volumes):
   ```bash
   ssh ... "docker inspect <container> --format '
   Networks: {{range \$k,\$v := .NetworkSettings.Networks}}{{\$k}} {{end}}
   Ports: {{json .HostConfig.PortBindings}}
   Restart: {{.HostConfig.RestartPolicy.Name}}
   Caps: {{json .HostConfig.CapAdd}}
   Devices: {{json .HostConfig.Devices}}
   Volumes: {{json .HostConfig.Binds}}
   '"
   ```

   **Secret env vars — use only for `docker run`, never write to a file:**
   ```bash
   # Get the full env for constructing the docker run command.
   # DO NOT redirect this to a file or paste it into a handoff/audit doc.
   ssh ... "docker inspect <container> --format '{{json .Config.Env}}'" | \
     jq -r '.[]'  # read in terminal only; do not save
   ```

   **If you must document which env vars a container needs**, record only the
   variable *names* with redacted values:
   ```bash
   ssh ... "docker inspect <container> --format '{{json .Config.Env}}'" | \
     jq -r '.[] | split("=")[0]' | sort  # names only, no values
   ```

2. Stop and remove the container:
   ```bash
   docker stop <container> && docker rm <container>
   ```
3. Recreate with `docker run` using the extracted config and the new image.
   Construct the `--env` flags from the env var output in your shell — do not
   save the secret values to any file.

**Record all manual recreations and pre-existing issues** in the audit report
for Phase 6 (handoff). **When recording, reference env var names only** (e.g.,
"container requires `OPENVPN_USER` and `OPENVPN_PASSWORD` env vars, which are
not in the vault") — never the values.

## Phase 4: Verify All Containers

After all updates are deployed, verify that every container is running and
healthy.

### 4a. List All Containers

```bash
ssh -i ~/.ssh/lzkmbp2016-micro-oracle ... \
  "docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}' | sort"
```

### 4b. Check for Unhealthy Containers

```bash
ssh ... "docker ps --filter health=unhealthy --format '{{.Names}}: {{.Status}}'"
```

If any containers are unhealthy, investigate their logs:

```bash
docker logs <container> --tail 20
```

### 4c. Check Key Service Health Endpoints

```bash
ssh ... '
echo -n "Traefik (https): "; curl -sk -o /dev/null -w "%{http_code}" https://localhost/ping; echo
echo -n "Authelia: "; curl -s -o /dev/null -w "%{http_code}" http://localhost:9091/api/health; echo
echo -n "Omnigent: "; curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/health; echo
echo -n "LiteLLM: "; curl -s -o /dev/null -w "%{http_code}" http://localhost:4000/health/liveliness; echo
'
```

### 4d. Investigate Restart Loops

If any container shows `Restarting (1) ...` status, check its logs and fix the
root cause. Common causes:

- **Custom command incompatible with new image**: Remove the custom command and
  rely on the image's default entrypoint + env vars.
- **Missing network**: The container references a network that doesn't exist.
  Find the correct network name with `docker network ls`.
- **Missing dependencies**: The container depends on another container that
  isn't running yet. Start the dependency first.

### 4e. Rollback Decision

If verification fails and the issue cannot be resolved in-place, decide
whether to roll back to the pre-update state:

1. **Can the issue be fixed by re-running a playbook or recreating a container?**
   → Fix in-place, re-verify.

2. **Is the issue caused by a breaking change in the new image version?**
   → Roll back the affected service's Ansible variable to the old version,
   re-run the playbook to recreate the container with the old image. Do NOT
   roll back the git tag — just revert the specific variable change.

3. **Are multiple services broken and the root cause is unclear?**
   → Full rollback to the pre-update tag (from Phase 0c):
   ```bash
   cd ~/p/gh/levonk/infrahub

   # Roll back levonk submodule
   ~/p/gh/levonk/skills-src/build/current/skills/software-dev/git-repository-management/scripts/git-rollback.sh \
     --to tags/updates/$(date -u +%Y/%m/%d)/service-update-pre --slug service-update-rollback levonk/

   # Roll back infrahub parent
   ~/p/gh/levonk/skills-src/build/current/skills/software-dev/git-repository-management/scripts/git-rollback.sh \
     --to tags/updates/$(date -u +%Y/%m/%d)/service-update-pre --slug service-update-rollback

   # Re-run all affected playbooks to recreate containers with old images
   # (repeat Phase 3 deploy steps with the reverted variables)
   ```
   Then re-verify (Phase 4a-4c) and abort the workflow. Generate a handoff
   (Phase 6) documenting what failed.

**Do NOT proceed to Phase 5 (commit) if verification failed and rollback was
performed.** The post-update tag should only be created on a verified-good
state.

## Phase 5: Commit Changes and Create Post-Update Tag

Commit the pinned version variable changes to git and create the post-update
rollback tag. This workflow modifies files in both the `infrahub` parent repo
and the `levonk` submodule.

### 5a. Run the Git Workflow

Use the [`infrahub-git`](infrahub-git.md) workflow, which runs the
`git-repository-management` skill on the infrahub project and all client
submodules. The skill's `git-commit-batch.sh` auto-creates
`tags/auto/YYYY/MM/...-{slug}-pre` and `-post` tags as part of the commit
batch.

### 5b. Files Typically Modified

| File | Repo | What Changes |
|------|------|--------------|
| `levonk/.../group_vars/cloud_servers.yml` | levonk submodule | Pinned image tags (e.g., traefik) |
| `levonk/.../host_vars/oci-cloud-server.yml` | levonk submodule | Pinned versions (e.g., authelia) |
| `shared/.../playbooks/deploy-local-registry.yml` | infrahub parent | Inline image references |

**Commit order**: levonk submodule first, then infrahub parent (to capture the
submodule reference update).

### 5c. Create Post-Update Tag

After the `infrahub-git` workflow has committed all changes, create an explicit
post-update tag in both repos (in addition to the auto-tags the git skill
already created):

```bash
cd ~/p/gh/levonk/infrahub

# Tag the levonk submodule
cd levonk
POST_TAG="tags/updates/$(date -u +%Y/%m/%d)/service-update-post"
git tag -a "$POST_TAG" -m "Post-update checkpoint: service update workflow completed"
echo "Levonk post-update tag: $POST_TAG"
cd ..

# Tag the infrahub parent
POST_TAG="tags/updates/$(date -u +%Y/%m/%d)/service-update-post"
git tag -a "$POST_TAG" -m "Post-update checkpoint: service update workflow completed"
echo "Infrahub post-update tag: $POST_TAG"
```

### 5d. Record Tag Summary

Record both pre-update and post-update tags for the handoff document and
audit report:

```
Git Tags Created:
  Pre-update:  tags/updates/YYYY/MM/DD/service-update-pre
  Post-update: tags/updates/YYYY/MM/DD/service-update-post
  (plus auto-tags from git-commit-batch.sh)

Rollback command:
  git-rollback.sh --to tags/updates/YYYY/MM/DD/service-update-pre
```

## Phase 6: Generate Handoff (If Pre-Existing Issues Found)

If the audit or deployment phases surfaced pre-existing issues (empty vault
credentials, missing images, broken roles, incompatible entrypoints), generate a
handoff document for follow-up in a future session.

Use the `handoff` skill to create a handoff document at
`.agents/handoffs/YYYY/MM/YYYYMMDDHHmm-oci-service-update-audit.md`.

**Include in the handoff**:

- All services updated (old image -> new image, method)
- All services held back (latest <2 days old, suggested pin)
- All pre-existing issues discovered (with file paths and root cause)
- All files modified (with paths)
- Next steps (fix vault, fix roles, update held-back services after cutoff)

### 6a. Mandatory Secret Scan Before Writing Handoff

**Before saving the handoff document**, scan the full content for secret
patterns. This is the last line of defense before secrets hit disk.

```bash
# Write the handoff content to a temp file first
HANDOFF_TMP=$(mktemp)
# <compose handoff content into $HANDOFF_TMP>

# Scan for secret patterns
rg -nE 'AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|sk-[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]+|AIza[0-9A-Za-z_-]{35}|-----BEGIN|://[^:]+:[^@]+@|[A-Z_]*(PASSWORD|PASS|SECRET|TOKEN|KEY)[A-Z_]*=[^\s]{8,}' \
  "$HANDOFF_TMP"

# If the scan finds anything, STOP and redact before saving
# Only after the scan is clean, move the file to its final location:
# mv "$HANDOFF_TMP" .agents/handoffs/YYYY/MM/YYYYMMDDHHmm-oci-service-update-audit.md
```

**If the scan finds any matches**: redact the values (replace with
`<redacted>`), re-scan to confirm clean, then save. **Never save a handoff
document that contains secret values.**

**When documenting vault issues**: reference the vault variable *names* (e.g.,
"`vault_nordvpn_openvpn_user` is empty in the vault") — never the values from
the running container's env vars.

## Known Pre-Existing Issues

These issues were discovered during the 2026-07-23 audit and may still be
present. Check before assuming they're fixed:

1. **NordVPN vault credentials empty**: `vault_nordvpn_openvpn_user` and
   `vault_nordvpn_openvpn_pass` are empty strings in
   `levonk/.../group_vars/infrahub-levonk-all.vault.yml`. The running container
   has credentials in its env vars. The `cloud-server-nordvpn.yml` playbook
   validation fails on this. **Fix**: Add the correct credentials to the vault
   (user must run `ansible-vault edit` interactively).

2. **Tor exit node image missing**: `localnet-proxy-tor:latest` doesn't exist on
   the server. The `vpn-tailscale` role tries to deploy it when
   `vpn_tailscale_tor_enabled: true`. **Fix**: Build the image or set
   `vpn_tailscale_tor_enabled: false`.

3. **tailscale-tor custom command incompatibility**: The `vpn-tailscale` role
   (lines 274-312 of `shared/.../roles/vpn-tailscale/tasks/main.yml`) sets a
   custom `command` that overrides the new tailscale image's `containerboot`
   entrypoint. **Fix**: Remove the custom command and rely on env vars
   (`TS_AUTHKEY`, `TS_HOSTNAME`, `TS_EXTRA_ARGS`).

4. **OmniRoute config push fails**: Non-critical post-deployment task in
   `deploy-ai-gateway-pipeline.yml` fails when pushing managed config to
   OmniRoute. **Fix**: Check OmniRoute API credentials and endpoint.

5. **cloud-server-vpn.yml missing infrastructure vars**: This playbook does not
   load infrastructure vars in pre_tasks, unlike `cloud-server-infra.yml`. It
   requires `-e @` for each infrastructure file. **Fix**: Add infrastructure
   var loading to the playbook's pre_tasks (consistent with
   `cloud-server-infra.yml`).

6. **cloud-server-nordvpn.yml missing infrastructure vars**: Same issue as
   above. **Fix**: Add infrastructure var loading to pre_tasks.

## Do Not

- **Do not start with a dirty repo** — Phase 0 must verify both repos are clean
  before any changes. A dirty repo means the pre-update tag captures unrelated
  changes, making rollback unsafe.
- **Do not skip the pre-update tag** — without it, there is no rollback point.
  Create it in Phase 0c before touching any Ansible variables.
- **Do not proceed to Phase 5 (commit) if Phase 4 (verify) failed** — the
  post-update tag marks a known-good state. If verification failed and rollback
  was performed, abort the workflow and generate a handoff.
- **Do not update images younger than 2 days old** — wait until they pass the
  age filter. Record them in the audit report for follow-up.
- **Do not use docker compose on remote servers** — per AGENTS.md architectural
  invariants, all container management must use `community.docker` Ansible
  modules.
- **Do not hardcode IP addresses or ports** — use infrastructure variables from
  `infrastructure/ports.yml` and `infrastructure/networks.yml`.
- **Do not commit secrets to git** — use Ansible vault for all credentials.
- **Do not copy secret values from `docker inspect` output into any file** —
  when documenting a container's config for manual recreation, record env var
  *names* only (e.g., `OPENVPN_USER=<redacted>`). The values are needed for the
  transient `docker run` command but must never be written to disk. See the
  "Policy: Secret Redaction" section and Phase 3e.
- **Do not edit the vault directly** — provide the user with a copyable
  `docker run` command for interactive `ansible-vault edit` (see AGENTS.md
  "Vault Edits (Agent → User Handoff)").
- **Do not skip the audit report** — always present findings to the user and
  get confirmation before deploying updates.
- **Do not ignore pre-existing issues** — record them in the handoff for
  follow-up, even if you worked around them manually.

## Suggested Skills

- **ansible** — Best practices for Ansible automation in infrahub. Used in
  Phase 3 for all playbook executions.
- **git-repository-management** — Commit workflow for pinned version changes
  across the infrahub parent repo and client submodules. Used in Phase 5.
- **handoff** — Capture session context for continuation. Used in Phase 6 when
  pre-existing issues are found.

---

## Context Declaration

### File Paths

- Workflow file: `.agents/workflows/infrahub-update-all.md`
- Ansible inventory: `levonk/active/02-config/ansible/inventories/oci.yml`
- Ansible playbooks: `shared/active/02-config/ansible/playbooks/`
- Ansible roles: `shared/active/02-config/ansible/roles/`
- Client group_vars: `levonk/active/02-config/ansible/inventories/group_vars/`
- Client host_vars: `levonk/active/02-config/ansible/host_vars/`
- Client vault: `levonk/active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml`
- Infrastructure vars: `shared/active/02-config/ansible/infrastructure/{ports,networks,domains,storage}.yml`
- Client infra overrides: `levonk/active/02-config/ansible/infrastructure/{ports,networks,domains,storage}.yml`
- Vault password: `~/.ansible/vault_password`
- SSH key: `~/.ssh/lzkmbp2016-micro-oracle`
- Handoff storage: `.agents/handoffs/YYYY/MM/`

### External Resources

- Docker Hub API: `https://hub.docker.com/v2/repositories/<repo>/tags/`
- GitHub Packages API: `https://api.github.com/orgs/<org>/packages/container/<image>/versions`
- cgr.dev API: `https://cgr.dev/v2/<image>/tags/list`

### Project Information

- Project: infrahub (parent) + levonk (submodule)
- Repository: `~/p/gh/levonk/infrahub`
- OCI server: `opc@100.90.22.85` (Tailscale IP)
- ADR Compliance: ADR-20260624001 (Hybrid Sensitive Information Storage),
  ADR-20260625001 (Infrastructure Consolidation)
