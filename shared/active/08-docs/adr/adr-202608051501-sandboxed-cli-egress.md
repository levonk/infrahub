---
modeline: "vim: set ft=markdown:"
title: "ADR: Sandboxed CLI Container Egress Control"
adr-id: "adr202608051501"
slug: "sandboxed-cli-egress"
url: "https://github.com/levonk/infrahub/blob/main/shared/active/08-docs/adr/adr-202608051501-sandboxed-cli-egress.md"
synopsis: "Use iron-proxy as a default-deny egress firewall for untrusted CLI containers (sherlock, recon tools, scrapers) with a two-layer architecture: Ansible-managed persistent proxy + just recipe for ephemeral CLI invocations. MITM mode with system trust store CA distribution. GET + HEAD + scoped POSTs method policy. Selectable deployment target (Mac or OCI) via inventory group membership."
author: "https://github.com/levonk"
date-created: "2026-08-05"
date-updated: "2026-08-05"
date-review: "2027-02-05"
date-triggers: ["2026-11-05"]
version: "0.1.0"
status: "accepted"
aliases: ["ADR-202608051501"]
tags: [doc/architecture/adr, sandbox, egress, iron-proxy, security, cli, container]
supersedes: []
superseded-by: []
related-to: ["hybrid-sensitive-information-storage", "infrastructure-consolidation", "container-build-strategy-mixed-arch"]
scope:
  impact-scope: [ansible-roles, justfile, cli-tools, iron-proxy, docker-networks, macos-hosts, oci-cloud-server]
  excluded-scope: [deployed-server-services, ai-proxy-chain, vpn-exit-nodes]
---

# Decision Record: Sandboxed CLI Container Egress Control

**Filename:** `adr-202608051501-sandboxed-cli-egress.md`

- belongs in `shared/active/08-docs/adr/` (existing repo convention for architecture decisions)

---

## Context

The infrahub repository contains server-side services deployed via Ansible roles — Traefik, Authelia, iron-proxy for AI workloads, VPN exit nodes, and so on. These are long-running, declaratively managed containers governed by the Architectural Invariants in `AGENTS.md`.

A separate class of container usage exists that is **not** covered by the server-service architecture: **CLI containers** — one-shot, interactive container invocations of untrusted or semi-trusted tools. The motivating example is `docker run -it --rm sherlock/sherlock`, but the class includes subdomain discovery (`projectdiscovery/subfinder`), web scrapers, recon tools, OSINT utilities, and any third-party CLI that makes outbound network calls and should not be trusted with unrestricted internet access.

These tools are not deployed services. They are ephemeral invocations: run, produce output to stdout, exit. They differ from server services in every dimension:

| Dimension | Server services | CLI containers |
|-----------|----------------|----------------|
| Lifecycle | Long-running, managed | Ephemeral, `--rm`, exit on completion |
| Management | Ansible `docker_container` (declarative) | `docker run` (imperative, one-shot) |
| State | Persistent volumes, configs | No volumes, read-only filesystem, tmpfs only |
| Network | Shared Docker networks (traefik-network, proxy-chain) | Isolated sandbox network |
| Trust | Trusted, first-party | Untrusted, third-party code |
| Egress | Restricted via deployed iron-proxy / Traefik | Must be default-deny, narrowly scoped |

**The problem**: Running `docker run -it --rm sherlock/sherlock` gives the container unrestricted outbound network access. The tool can contact any host, use any HTTP method, exfiltrate data to any endpoint. There is no egress boundary, no audit log, no method restriction.

**The requirement**: Run untrusted CLI containers with:

1. Default-deny egress — only explicitly allowlisted hosts reachable
2. HTTP method restriction — GET + HEAD + scoped POSTs only
3. Filesystem isolation — no access to host filesystem outside stdin/stdout
4. Audit trail — every outbound request logged with host, method, path, status
5. Reusability — a framework, not a one-off sherlock wrapper

**Relevant prior art in the repo**: The `proxy-iron-proxy` role already deploys [iron-proxy](https://github.com/ironsh/iron-proxy) — a default-deny egress firewall whose upstream documentation has a dedicated ["Sandboxed Code Execution" use case](https://docs.iron.sh/use-cases/sandboxed-code). The existing role deploys it for the AI proxy chain (allowlisting OpenAI, Anthropic, Google, GitHub). The allowlist rules in the existing template already support per-host `methods:` and `paths:` restrictions, so "HTTP GET only to search engines + social networks" is a direct config fit, not a new feature.

## Constraints

- **Architectural Invariant #1** (`shared/` is client-agnostic): The role and its defaults must contain no client-specific values (allowlists, IPs, ports). Client-specific values live in `<client>/active/02-config/ansible/`.
- **Architectural Invariant #4** (Ansible modules manage containers, never `docker compose`): The persistent proxy is deployed via `community.docker.docker_container`.
- **Architectural Invariant #5** (Services run in containers): The proxy is a container, not a host-level binary.
- **IP and Port Rules**: All IPs and ports must be `infra_*` variables in the client's `infrastructure/` files, never hardcoded.
- **Host Mutation Policy**: Ephemeral CLI containers that do not touch host or app state are explicitly carved out ("Operations inside a throwaway container that does not touch host or app state"). The persistent proxy deployment IS a host mutation and must go through Ansible.
- **ADR-20260624001** (Hybrid Secret Storage): If API key injection is added later, keys come from client vault, never in `shared/`.
- **ADR-20260625001** (Infrastructure Consolidation): All network topology (subnet, gateway, IP) and port assignments go in `infrastructure/*.yml` with `infra_` naming convention.
- **ADR-20260709001** (Container Build Strategy): Use pre-built upstream images (Branch A: Wrap Pre-Built) for both iron-proxy and CLI tools. No building.
- **AGENTS.md commit policy**: No advertising or attribution boilerplate in files or commit messages.

## Decision

Adopt a **two-layer architecture** using iron-proxy as the egress boundary for sandboxed CLI containers, with deployment selectable between the control machine (Mac) and the OCI cloud server via inventory group membership.

### Layer 1: Ansible-Managed Persistent Proxy

A new role `sandbox-cli-proxy` deploys a dedicated iron-proxy instance as a long-running container via `community.docker.docker_container`. This is a real deployment governed by the Deployment Workflow Rule — it targets an inventory host, uses infra variables, and is idempotent.

This is a **separate iron-proxy instance** from the existing `proxy-iron-proxy` role used for the AI proxy chain. The AI proxy chain has its own allowlist (OpenAI, Anthropic, Google, GitHub) and network (`proxy-chain-network`). The sandbox proxy has a CLI-egress allowlist (search engines, social networks) and a dedicated network (`sandbox-net`). Mixing them would violate least-privilege: a sherlock run should not be able to reach `api.openai.com`.

### Layer 2: `just` Recipe for Ephemeral CLI Invocations

A `just sandbox-run <profile> <image> <args>` recipe runs the CLI container via `docker run --rm -it`, pointing at the deployed proxy. This is a throwaway container invocation, not a deployment. It fits the Host Mutation Policy carve-out for "operations inside a throwaway container that does not touch host or app state."

**Why not `community.docker.docker_container` for the CLI container?** Ansible's container module is designed for declarative state management ("ensure this container is running"). CLI containers are imperative: run, stream stdout to the terminal, exit, tear down. Forcing them through `docker_container` would require a `state: started` task followed by a `docker logs` / `docker wait` polling loop — fighting the module's design and losing interactive TTY support. The proxy is the managed service; the CLI is the unmanaged workload. This split mirrors how iron-proxy itself describes its architecture: the proxy is the boundary, the workload is ephemeral.

### Deployment Target: Selectable via Inventory

The role targets a `sandbox_proxy_hosts` inventory group. Clients choose where to deploy by adding hosts to this group:

- **Mac (the control Mac)** — zero network latency for local CLI runs, no Tailscale dependency. Requires Docker/OrbStack on the Mac.
- **OCI cloud server** — shared audit log with other infrastructure, central management. CLI containers on the Mac route over Tailscale, adding latency.
- **Both** — the role supports multiple targets. Each gets its own infra vars (ports, network, IP) and its own allowlist if desired. The `just` recipe selects which proxy to route through via the generated `.sandbox-env` file.

### TLS Mode: MITM with System Trust Store

iron-proxy operates in MITM mode to enable method and path enforcement on HTTPS traffic. SNI-only mode would restrict the allowlist to host-level only — "GET only" could not be enforced on HTTPS, which is where all modern search engines and social networks live.

**CA certificate distribution**: The proxy generates a CA on first run. CLI containers must trust it. The primary mechanism is **system trust store installation** — the CA is mounted into the container's system CA directory and `update-ca-certificates` (or equivalent) runs on container entry. This is more transparent and more flexible than env-var-only approaches:

- **Transparent**: All tools that use the system trust store (Go binaries, curl, wget, system Python) work without per-tool configuration. The CA is trusted at the OS level, not per-library.
- **Flexible**: Tools that don't respect `REQUESTS_CA_BUNDLE` or `SSL_CERT_FILE` (common with statically-linked Go binaries) still work.
- **Fallback**: `REQUESTS_CA_BUNDLE` and `SSL_CERT_FILE` env vars are also set, so Python tools that check env vars before the system store work too.

The `just` recipe handles per-image CA installation via an optional entrypoint wrapper. For Alpine-based images: mount CA to `/usr/local/share/ca-certificates/sandbox-ca.crt`, run `update-ca-certificates`, then `exec` the original entrypoint. For Debian-based images: same path, same command. For images with no `update-ca-certificates`, fall back to `REQUESTS_CA_BUNDLE` / `SSL_CERT_FILE` env vars only.

### Method Policy: GET + HEAD + Scoped POSTs

The allowlist enforces `methods: ["GET", "HEAD"]` as the default for all allowlisted hosts. Per-host `rules` entries add scoped POSTs where a specific tool requires them (e.g., a search endpoint that requires POST). The allowlist is default-deny: anything not matched returns 403.

This is a policy decision, not a technical one. Strict GET-only breaks tools that POST to search endpoints. GET + HEAD + scoped POSTs is the pragmatic balance: the audit log shows every request, and the allowlist can be tightened per-host.

### Profile-Based Allowlist for a Class of Tools

The role supports multiple named profiles (e.g., `osint`, `recon`, `scrape`), each with its own allowlist. This is implemented as multiple iron-proxy instances on different ports/networks, each with a profile-specific config. The `just` recipe selects the profile by name, routing through the corresponding proxy instance.

For the initial implementation, a single `osint` profile covers sherlock and similar tools (search engines + social networks, GET + HEAD). New profiles are added by: (1) adding infra vars for the new profile's ports/network, (2) adding allowlist vars for the new profile, (3) the role loops over profiles to deploy multiple proxy instances.

## Rationale

### Why iron-proxy (not Squid, mitmproxy, or Envoy)?

The repo already deploys iron-proxy via the `proxy-iron-proxy` role for the AI proxy chain. iron-proxy is purpose-built for this exact use case — its upstream documentation has a dedicated "Sandboxed Code Execution" use case page. The comparison from the iron-proxy docs:

| | iron-proxy | Squid | mitmproxy | Envoy |
|---|---|---|---|---|
| Default-deny egress | Built-in | Requires complex ACL config | Requires custom scripting | Requires RBAC/filter config |
| Method/path restriction | Built-in per-host rules | ACL config | Custom scripting | RBAC config |
| Secret injection | Built-in | No | No | No |
| Structured audit logging | Built-in, per-request JSON | Basic access logs | Plugin-based | Configurable access logs |
| Setup complexity | Single binary + YAML | Extensive config language | Python scripting | Complex YAML/control plane |

Using a different tool would mean introducing a new dependency, new config format, and new operational pattern for a problem the existing tool already solves.

### Why a separate role (not extending `proxy-iron-proxy`)?

The existing `proxy-iron-proxy` role deploys iron-proxy for the AI proxy chain with a specific allowlist (OpenAI, Anthropic, Google, GitHub), a specific network (`proxy-chain-network`), and specific credential injection. The sandbox CLI use case has a different allowlist (search engines, social networks), a different network (`sandbox-net`), no credential injection (initially), and a different deployment target (Mac or OCI, not just OCI).

Extending `proxy-iron-proxy` to handle both would require complex conditional logic, multiple allowlist variables, and network selection — violating the single-responsibility principle. A separate role keeps each deployment clean and allows them to evolve independently.

### Why MITM mode (not SNI-only)?

SNI-only mode cannot enforce method or path restrictions on HTTPS traffic. Since all modern search engines and social networks use HTTPS, SNI-only would reduce the allowlist to host-level only — "GET only" could not be enforced. The user's explicit requirement is HTTP GET-only enforcement, which requires TLS termination.

MITM mode requires CA certificate distribution to CLI containers, which adds operational complexity. This is accepted as the cost of method-level enforcement on HTTPS.

### Why `just` recipe for CLI invocations (not Ansible)?

The Host Mutation Policy carves out "operations inside a throwaway container that does not touch host or app state" as NOT a host mutation. CLI container invocations are exactly this. Ansible's `community.docker.docker_container` is designed for declarative state management, not imperative "run, stream, exit" workflows. Using Ansible for the CLI invocation would:

- Lose interactive TTY support (`-it` flag)
- Require polling loops (`docker wait`, `docker logs`) instead of direct stdout streaming
- Add Ansible overhead (inventory resolution, fact gathering) to every invocation
- Fight the module's design (state management vs. one-shot execution)

The proxy is the managed service (Ansible). The CLI is the ephemeral workload (`just` / `docker run`). This separation is architecturally clean and operationally practical.

## Technical Approach

### File Layout

```
shared/active/02-config/ansible/
  roles/
    sandbox-cli-proxy/                    # NEW — reusable, client-agnostic
      defaults/main.yml                   # Neutral defaults (image, TLS mode, profile loop)
      tasks/main.yml                      # docker_network + docker_container per profile
      templates/iron-proxy.yml.j2         # Allowlist config (renders from client vars)
      meta/main.yml
      README.md
  playbooks/
    deploy-sandbox-proxy.yml              # NEW — targets sandbox_proxy_hosts group

levonk/active/02-config/ansible/
  inventories/
    macos-hosts.yml                       # Add macOS hosts to sandbox_proxy_hosts
  group_vars/
    sandbox_proxy_hosts.yml               # NEW — client allowlist + profile definitions
  infrastructure/
    ports.yml                             # Add infra_port_sandbox_proxy_* vars
    networks.yml                          # Add infra_network_sandbox_* vars
    storage.yml                           # Add infra_storage_sandbox_* vars

justfile                                  # Add sandbox-run + sandbox-* recipes
```

### Role Defaults (neutral, no client values)

```yaml
sandbox_cli_proxy_enabled: true
sandbox_cli_proxy_image: "ironsh/iron-proxy"
sandbox_cli_proxy_version: "0.7.0"  # pin, never float latest

# TLS mode — MITM required for method/path enforcement on HTTPS
sandbox_cli_proxy_tls_mode: "mitm"

# Allowlist — EMPTY in shared defaults. Client must populate.
sandbox_cli_proxy_allowlist_warn: false  # enforce, don't just log
sandbox_cli_proxy_profiles: []  # list of profile dicts, populated by client

# CA cert — path on host for mounting into CLI containers
sandbox_cli_proxy_ca_dir: "{{ infra_storage_sandbox_ca_dir | default('/opt/sandbox-cli') }}"
```

### Client Vars (the actual policy)

```yaml
# levonk/active/02-config/ansible/group_vars/sandbox_proxy_hosts.yml
sandbox_cli_proxy_profiles:
  - name: "osint"
    network: "{{ infra_network_sandbox_osint_name }}"
    subnet: "{{ infra_network_sandbox_osint_subnet }}"
    gateway: "{{ infra_network_sandbox_osint_gateway }}"
    proxy_ip: "{{ infra_network_sandbox_osint_proxy_ip }}"
    http_port: "{{ infra_port_sandbox_osint_http }}"
    https_port: "{{ infra_port_sandbox_osint_https }}"
    dns_port: "{{ infra_port_sandbox_osint_dns }}"
    allowlist_rules:
      # Search engines — GET + HEAD only
      - host: "*.google.com"
        methods: ["GET", "HEAD"]
        paths: ["/*"]
      - host: "*.bing.com"
        methods: ["GET", "HEAD"]
        paths: ["/*"]
      - host: "duckduckgo.com"
        methods: ["GET", "HEAD"]
        paths: ["/*"]
      # Social networks — GET + HEAD for scraping
      - host: "*.twitter.com"
        methods: ["GET", "HEAD"]
        paths: ["/*"]
      - host: "*.x.com"
        methods: ["GET", "HEAD"]
        paths: ["/*"]
      - host: "*.instagram.com"
        methods: ["GET", "HEAD"]
        paths: ["/*"]
      - host: "*.linkedin.com"
        methods: ["GET", "HEAD"]
        paths: ["/*"]
      - host: "*.facebook.com"
        methods: ["GET", "HEAD"]
        paths: ["/*"]
```

### Infrastructure Vars

```yaml
# levonk/active/02-config/ansible/infrastructure/ports.yml
infra_port_sandbox_osint_http: "18080"
infra_port_sandbox_osint_https: "18443"
infra_port_sandbox_osint_dns: "18053"

# levonk/active/02-config/ansible/infrastructure/networks.yml
infra_network_sandbox_osint_name: "sandbox-osint-net"
infra_network_sandbox_osint_subnet: "172.40.0.0/16"
infra_network_sandbox_osint_gateway: "172.40.0.1"
infra_network_sandbox_osint_proxy_ip: "172.40.0.2"

# levonk/active/02-config/ansible/infrastructure/storage.yml
infra_storage_sandbox_ca_dir: "/opt/sandbox-cli"
```

### `just` Recipe

```makefile
# justfile
sandbox-env := "{{ justfile_directory() }}/.sandbox-env"

# Run a sandboxed CLI tool through the iron-proxy egress boundary.
# Usage: just sandbox-run osint sherlock/sherlock "target.com"
sandbox-run profile image *args:
    #!/usr/bin/env bash
    set -euo pipefail
    source {{ sandbox-env }}
    eval "export ${profile^^}_VARS"
    docker run --rm -i \
      --network "${SANDBOX_NETWORK}" \
      --read-only \
      --tmpfs /tmp:rw,size=64m \
      --cap-drop ALL \
      --security-opt no-new-privileges \
      --user 1000:1000 \
      -e HTTP_PROXY="http://${SANDBOX_PROXY_HOST}:80" \
      -e HTTPS_PROXY="http://${SANDBOX_PROXY_HOST}:443" \
      -e REQUESTS_CA_BUNDLE="${SANDBOX_CA_CERT_CONTAINER_PATH}" \
      -e SSL_CERT_FILE="${SANDBOX_CA_CERT_CONTAINER_PATH}" \
      -v "${SANDBOX_CA_CERT_HOST_PATH}:${SANDBOX_CA_CERT_SYSTEM_PATH}:ro" \
      --entrypoint sh \
      "{{ image }}" \
      -c "update-ca-certificates 2>/dev/null || true; exec {{ args }}"

# Convenience wrappers
sandbox-sherlock target: (sandbox-run "osint" "sherlock/sherlock" target)
sandbox-subfinder domain: (sandbox-run "osint" "projectdiscovery/subfinder" "-d" domain)
```

### CA Certificate Distribution

The role's task flow:

1. `community.docker.docker_volume` — create a volume for iron-proxy's `/etc/iron-proxy/` (CA cert + key storage)
2. `community.docker.docker_container` — start iron-proxy with the volume
3. `ansible.builtin.command: docker cp` — extract `ca.crt` from the running container to `sandbox_cli_proxy_ca_dir` on the host
4. `ansible.builtin.file` — set ownership on the CA file (readable by the user who runs `just sandbox-*` recipes)
5. `ansible.builtin.template` — render `.sandbox-env` file with resolved variable values for the `just` recipes to source

The `just` recipe mounts the CA into the container's system CA directory (`/usr/local/share/ca-certificates/sandbox-ca.crt` on Alpine/Debian) and runs `update-ca-certificates` on entry before `exec`-ing the original command. `REQUESTS_CA_BUNDLE` and `SSL_CERT_FILE` env vars are also set as a fallback for tools that check env vars before the system store.

## Affected Components

### People
- **DevOps Engineers**: Need to understand the two-layer architecture (proxy vs. CLI invocation) and when to use which layer.
- **Security Team**: Need to review allowlist policies and audit logs.
- **Tool Users**: Need to use `just sandbox-*` recipes instead of bare `docker run` for untrusted CLI tools.

### Processes
- **Adding a new CLI tool**: Add a `sandbox-<tool>` recipe alias. If the tool needs a different allowlist, add a new profile.
- **Adding a new allowlist profile**: Add infra vars (ports, network), add profile to `sandbox_cli_proxy_profiles`, redeploy the role.
- **Auditing egress**: Review iron-proxy's structured JSON logs (every request logged with host, method, path, status, policy decision).

### Components
- **iron-proxy**: Egress firewall, deployed as a container
- **Docker networks**: Dedicated `sandbox-*` networks per profile
- **`just` recipes**: Ephemeral CLI invocation wrappers
- **Ansible role `sandbox-cli-proxy`**: Proxy deployment and config
- **Client infrastructure files**: Ports, networks, storage paths
- **Client group_vars**: Allowlist policy definitions

## Consequences

### Negative

**Complexity:**
- MITM mode requires CA certificate distribution per CLI container
- Per-image entrypoint wrapper for `update-ca-certificates` (Alpine vs Debian vs images without it)
- Multiple iron-proxy instances if multiple profiles are used

**Operational:**
- CA certificate must be regenerated if the proxy's CA volume is lost
- CLI containers that pin certificates or use certificate transparency will reject the MITM CA
- Adding a new allowlist host requires redeploying the proxy (not dynamic)

**Security trade-offs:**
- MITM mode means iron-proxy can see all HTTPS traffic in plaintext (by design — it's the egress inspection boundary). This is the accepted cost of method/path enforcement.
- `update-ca-certificates` on entry adds startup latency to every CLI run

### Positive

**Security:**
- Default-deny egress for untrusted CLI containers — no unrestricted internet
- Method-level enforcement on HTTPS (GET + HEAD + scoped POSTs)
- Per-request audit log with host, method, path, status, policy decision
- Filesystem isolation (read-only, tmpfs, no host mounts except CA cert)
- IMDS and loopback blocked by iron-proxy's `upstream_deny_cidrs`

**Operations:**
- Reusable framework — new CLI tools need only a recipe alias
- Profile-based allowlists — different tools get different egress scopes
- Selectable deployment target — Mac for low latency, OCI for central audit
- No build infrastructure — both proxy and CLI images are pre-built upstream

**Compliance:**
- Follows all Architectural Invariants (Ansible-managed proxy, infra vars, shared/ client-agnostic, containers not systemd)
- Follows ADR-20260624001 (secrets in client vault if added later)
- Follows ADR-20260625001 (infra vars for all topology)
- Follows ADR-20260709001 (pre-built upstream images, no building)

### Neutral

**Performance:**
- MITM TLS termination adds ~1-5ms per request (negligible for CLI tools)
- CA installation on entry adds ~0.5-2s per container start
- Mac deployment: zero network latency. OCI deployment: Tailscale latency per request.

**Scalability:**
- One iron-proxy instance per profile. Scales linearly with profile count.
- Each profile is a separate Docker network — no cross-profile traffic.

## Alternatives Considered

### Alternative 1: Extend `proxy-iron-proxy` role

**Description**: Add sandbox CLI support to the existing iron-proxy role with conditional logic for different allowlists and networks.

**Rejected**: Violates single-responsibility. The AI proxy chain and the CLI sandbox have different allowlists, networks, deployment targets, and credential requirements. Merging them creates complex conditional logic and risks accidental allowlist leakage between use cases.

### Alternative 2: SNI-only TLS mode

**Description**: Use iron-proxy in SNI-only mode to avoid CA certificate distribution.

**Rejected**: SNI-only mode cannot enforce method or path restrictions on HTTPS. Since the user's requirement is HTTP GET-only enforcement and all modern search engines and social networks use HTTPS, SNI-only reduces the policy to host-level only — insufficient.

### Alternative 3: `docker run` with `--network none`

**Description**: Run CLI containers with no network access at all.

**Rejected**: CLI tools like sherlock require network access to function. The requirement is restricted egress, not no egress.

### Alternative 4: Host-level firewall rules (nftables/ufw)

**Description**: Use the existing `proxy-firewall` role to restrict egress from CLI containers at the host firewall level.

**Rejected**: Host firewall rules apply to all containers on the host, not just sandboxed CLI containers. They also operate at the IP/CIDR level, not the HTTP method/path level. Cannot enforce "GET only" or "search engines only" — only "these IPs only." Would require maintaining a list of all search engine and social network IPs, which change constantly.

### Alternative 5: Ansible `community.docker.docker_container` for CLI invocations

**Description**: Use Ansible to manage the CLI container lifecycle too, not just the proxy.

**Rejected**: `community.docker.docker_container` is designed for declarative state management, not imperative "run, stream stdout, exit" workflows. Using it for CLI invocations would lose interactive TTY support, require polling loops, and fight the module's design. The Host Mutation Policy explicitly carves out throwaway container operations as not requiring Ansible.

## Rollout / Migration

### Phase 1: ADR and Design (Current)
- [x] Create ADR documenting the sandboxed CLI egress architecture
- [x] Define role, playbook, variable, and recipe structure
- [x] Validate compliance with all Architectural Invariants

### Phase 2: Core Implementation
- [ ] Create `sandbox-cli-proxy` role (defaults, tasks, templates, meta)
- [ ] Create `deploy-sandbox-proxy.yml` playbook
- [ ] Add `sandbox_proxy_hosts` group to inventory
- [ ] Add infra vars (ports, networks, storage) to client infrastructure files
- [ ] Add client allowlist vars to `group_vars/sandbox_proxy_hosts.yml`
- [ ] Add `just sandbox-run` + `sandbox-sherlock` recipes

### Phase 3: CA Certificate Flow
- [ ] Implement CA extraction from iron-proxy container
- [ ] Implement `.sandbox-env` generation
- [ ] Test CA trust with Python-based tools (sherlock)
- [ ] Test CA trust with Go-based tools (subfinder)

### Phase 4: Validation
- [ ] Deploy proxy to Mac, run sherlock through it, verify audit logs
- [ ] Verify default-deny: attempt to reach non-allowlisted host, confirm 403
- [ ] Verify method enforcement: attempt POST to GET-only host, confirm 403
- [ ] Verify filesystem isolation: confirm no host filesystem access
- [ ] Deploy proxy to OCI, run CLI from Mac over Tailscale, verify latency

### Phase 5: Profile Expansion
- [ ] Add second profile (e.g., `recon`) with different allowlist
- [ ] Verify profile isolation (traffic from profile A cannot reach profile B's hosts)

### Rollback Plan
If issues arise:
1. Remove `sandbox-cli-proxy` role and playbook
2. Remove `sandbox_proxy_hosts` group from inventory
3. Remove infra vars and client vars
4. Remove `just sandbox-*` recipes
5. The existing `proxy-iron-proxy` role (AI proxy chain) is unaffected — it is a separate role, network, and deployment

## To Investigate

1. **iron-proxy version pinning**: Verify `0.7.0` is the right pinned version (check for security patches, OTel export support)
2. **Per-image CA installation**: Catalogue which CLI tool images need `update-ca-certificates` vs which respect `REQUESTS_CA_BUNDLE` / `SSL_CERT_FILE` natively
3. **Audit log shipping**: Pipe iron-proxy's JSON logs to the existing CrowdSec / Wazuh stack for centralized egress auditing
4. **Dynamic allowlist updates**: iron-proxy supports a control plane for dynamic policy updates without restart — evaluate if this is needed for the CLI sandbox use case
5. **Credential injection**: If a CLI tool needs API keys (e.g., a recon tool with a Shodan API key), evaluate using iron-proxy's `secrets` transform to inject at the boundary so the CLI container never sees the key

## Validation

**Success Metrics:**
- Untrusted CLI containers can only reach explicitly allowlisted hosts
- HTTP method restrictions are enforced on HTTPS traffic (GET-only hosts reject POST)
- Every outbound request appears in the audit log with host, method, path, status, and policy decision
- CLI containers have no access to host filesystem outside stdin/stdout
- New CLI tools can be added with a single `just` recipe alias
- The same role deploys to both Mac and OCI via inventory group selection

**Failure Conditions:**
- CLI container reaches a non-allowlisted host
- POST to a GET-only host succeeds
- CLI container can read or write host files
- Audit log is missing entries for outbound requests
- Adding a new CLI tool requires changes to the Ansible role (should only need a recipe alias + optionally a new profile)

## Review Schedule

**Review Date:** 2027-02-05 (6 months from adoption)

**Review Triggers:**
- A CLI tool is found that cannot function under the egress restrictions
- A security incident related to CLI container egress
- iron-proxy releases a significant new version (especially around MITM or allowlist features)
- Need to add credential injection for a CLI tool
- Profile count grows beyond 3 (evaluate if the multi-instance approach scales)

## Notes

- The initial implementation covers a single `osint` profile. The multi-profile architecture is designed in but not built out until a second profile is needed.
- The CA certificate distribution is the most fragile part of the design. Per-image entrypoint wrappers may need maintenance as new CLI tools are added.
- The `just` recipe's `--entrypoint sh -c "update-ca-certificates ...; exec ..."` pattern assumes the image has `sh` and `update-ca-certificates`. Images that lack either need a different approach (e.g., a sidecar init container, or a custom wrapper image).
- Current state of decisions belongs in `decisions.md` if the repo maintains one. Implementation details belong in the role and playbook files.

## References

- [iron-proxy GitHub](https://github.com/ironsh/iron-proxy)
- [iron-proxy docs — Sandboxed Code Execution](https://docs.iron.sh/use-cases/sandboxed-code)
- [iron-proxy docs — Configuration](https://docs.iron.sh/reference/configuration)
- [iron-proxy docs — Host Allowlist](https://docs.iron.sh/policies/host-allowlist)
- ADR-20260624001: Hybrid Sensitive Information Storage Strategy
- ADR-20260625001: Infrastructure Consolidation Strategy
- ADR-20260709001: Container Build Strategy for Mixed-Architecture Fleets
- AGENTS.md: Architectural Invariants (especially #1, #4, #5)
- AGENTS.md: Host Mutation Policy (throwaway container carve-out)
- Existing role: `shared/active/02-config/ansible/roles/proxy-iron-proxy/`
- Decision record workflow: `skills-src/build/current/workflows/general/decision-record.md`

<!-- vim: set ft=markdown: -->
