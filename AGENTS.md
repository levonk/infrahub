# Agent Guidelines for localnet

## CRITICAL: Environment Configuration for Devbox/Nix

**MANDATORY PRE-REQUISITE**: Before running any devbox or Nix commands, you MUST ensure the Nix environment is properly configured in your PATH.

### Environment Setup Rule

**ALWAYS** check and add Nix paths to PATH before attempting to use devbox:

```bash
# Check for Nix binary and add to PATH if found
if [ -z "$NIX_PATH" ] || ! command -v nix >/dev/null 2>&1; then
    # Try common Nix installation locations
    for nix_path in /nix/var/nix/profiles/default/bin/nix ~/.nix-profile/bin/nix /usr/local/bin/nix /usr/bin/nix; do
        if [ -x "$nix_path" ]; then
            export NIX_PATH="$(dirname "$nix_path"):${NIX_PATH:-}"
            export PATH="$(dirname "$nix_path"):$PATH"
            break
        fi
    done
    
    # Source Nix environment if available
    if [ -f /etc/profile.d/nix.sh ]; then
        . /etc/profile.d/nix.sh
    elif [ -f ~/.nix-profile/etc/profile.d/nix.sh ]; then
        . ~/.nix-profile/etc/profile.d/nix.sh
    fi
fi

# Check for devbox and add global shim if available
if ! command -v devbox >/dev/null 2>&1; then
    if [ -x ~/.local/share/devbox/global/shims/devbox ]; then
        export PATH="$HOME/.local/share/devbox/global/shims:$PATH"
    elif [ -x /usr/local/bin/devbox ]; then
        export PATH="/usr/local/bin:$PATH"
    fi
fi

# Verify environment
echo "Nix: $(command -v nix || echo 'NOT FOUND')"
echo "Nix: $(nix --version || echo 'NOT FOUND')"
echo "Devbox: $(command -v devbox || echo 'NOT FOUND')"
echo "Devbox: $(devbox version || echo 'NOT FOUND')"
echo "rtk: $(devbox run -- command -v rtk || echo 'NOT FOUND')"
echo "rtk: $(devbox run -- rtk -V || echo 'NOT FOUND')"
echo "Just: $(devbox run -- command -v just || echo 'NOT FOUND')"
echo "Just: $(devbox run -- just -V || echo 'NOT FOUND')"
```

### CRITICAL RULE

**NEVER** attempt to work around using devbox by trying alternative methods. Always use devbox:

1. ✅ **DO**: Ensure Nix paths are in PATH
2. ✅ **DO**: Use `devbox run -- rtk <command>`
3. ❌ **DO NOT**: Try to run commands directly without devbox
4. ❌ **DO NOT**: Skip devbox and try system binaries
5. ❌ **DO NOT**: Claim "devbox not found" and give up - FIX THE PATH

### Ansible Vault Password

**ALWAYS** use the vault password file at `~/.ansible/vault_password` for Ansible vault operations:

```bash
devbox run -- rtk ansible-playbook -i inventory.yml playbook.yml --vault-password-file ~/.ansible/vault_password
```

This is the standard location for Ansible vault passwords in this project.

### CRITICAL: Secret/Key Handling Policy

**NEVER** share API keys, passwords, tokens, or any secret/private information in open communication unless explicitly requested by the user.

**Secret Storage Strategy:**
This project follows a hybrid secret storage approach as defined in [ADR-20260624001: Hybrid Sensitive Information Storage Strategy](shared/active/08-docs/adr/adr-20260624001-hybrid-sensitive-information-storage.md). Key principles:

- **Per-Client Central Vault**: All shared secrets stored in client-specific vault files (e.g., `levonk/active/02-config/ansible/group_vars/infrahub-levonk-all.vault.yml`)
- **Shared Path Clean**: The `shared/` directory must NEVER contain sensitive information
- **In-Service Transient Secrets**: Service-specific transient secrets (JWT tokens, session keys) stored within service configurations
- **Ansible Variable Distribution**: Use Ansible vault variables for secure distribution at runtime

**When referring to vault credentials or secrets:**
- ✅ **DO**: Provide the exact command with full paths for the user to retrieve the key themselves
- ✅ **DO**: Reference variable names or configuration keys without revealing their values
- ✅ **DO**: Follow the hybrid storage strategy defined in the ADR
- ❌ **DO NOT**: Display actual secret values in responses
- ❌ **DO NOT**: Log or output secrets in command results
- ❌ **DO NOT**: Include secrets in documentation or comments
- ❌ **DO NOT**: Place secrets in the `shared/` directory

**Example - Correct approach:**
```bash
# To view the CrowdSec bouncer API key:
devbox run -- ansible-vault view /Users/micro/p/gh/levonk/infrahub/levonk/active/02-config/ansible/group_vars/infrahub-levonk-all.vault.yml --vault-password-file ~/.ansible/vault_password
```

**Example - Incorrect approach:**
❌ "The CrowdSec API key is: 03d8c0b493fb43238d739904dfe548577f69f9d81f2ef25d4b74e73695338649"

**Exception**: Only reveal secret values when the user explicitly asks for them (e.g., "show me the API key", "what is the password?").

### Verification

Before running any devbox command, verify:

```bash
# These must succeed before proceeding
command -v nix
command -v devbox
devbox run -- command -v just
```

If any of these fail, add the appropriate paths to PATH before proceeding.

## Security Audit Guidelines

### Security Audit Playbooks

All cloud server deployments must include a final security audit playbook (`final-audit.yml`) that validates:

**Critical Security Checks:**
- SSH connectivity and configuration
- No hardcoded IPs/ports in deployed configs (excluding comments)
- SSH hardening: PermitRootLogin (no or prohibit-password), PasswordAuthentication (no), ed25519-only keys
- Firewall default-deny policy enforcement
- fail2ban service and jail status
- Docker daemon hardening (userns-remap or no-new-privileges)
- Automatic security updates (dnf-automatic for RedHat, unattended-upgrades for Debian)
- Container image ages (warning for images >30 days old)

**Non-Critical Warnings:**
- Container image age warnings should not fail the audit
- Use separate `security_warnings` list for non-critical issues

**Playbook Pattern:**
```yaml
- name: "Final Security Audit"
  hosts: cloud_servers
  become: true
  gather_facts: true
  vars:
    audit_results: {}
    security_gaps: []
    security_warnings: []
```

### SSH Hardening Best Practices

**PermitRootLogin Settings:**
- `no` - Disables root login entirely (most secure)
- `prohibit-password` - Allows root login only with SSH keys (acceptable for Oracle Cloud)
- Both are considered secure in security audits

**Key Types:**
- Use ed25519 keys only (remove RSA, ECDSA, DSA host keys)
- Update `HostKey` directives in `/etc/ssh/sshd_config` to only include ed25519

### Container Image Management

**Image Age Monitoring:**
- Container images older than 30 days should trigger warnings
- Use `docker images --format '{% raw %}{{.Repository}}:{{.Tag}} {{.CreatedSince}}{% endraw %}'` to check ages
- Update images regularly to include security patches
- Pin to specific tags for production, not just `latest`

## IP and Port Configuration Rules

### CRITICAL: All IP Addresses and Ports Must Be Variables

**ABSOLUTELY FORBIDDEN**: Hardcoded IP addresses and port numbers in configuration files, especially in Ansible tasks and Docker Compose files.

**REQUIRED**: All IP addresses and port numbers must be defined as variables.

#### Examples of Violations

**❌ FORBIDDEN - Hardcoded ports in Ansible tasks:**
```yaml
ports:
  - "8888:8888/tcp"
  - "8388:8388/tcp"
  - "8388:8388/udp"
  - "6881:6881/udp"
```

**❌ FORBIDDEN - Hardcoded container ports:**
```yaml
ports:
  - "{{ proxy_http_transparent_port }}:80/tcp"
  - "{{ proxy_https_transparent_port }}:443/tcp"
  - "{{ proxy_envoy_internal_host_port }}:3129/tcp"
  - "{{ proxy_envoy_admin_host_port }}:9901/tcp"
```

**✅ REQUIRED - All ports as variables:**
```yaml
ports:
  - "{{ proxy_http_transparent_port }}:{{ proxy_http_container_port }}/tcp"
  - "{{ proxy_https_transparent_port }}:{{ proxy_https_container_port }}/tcp"
  - "{{ proxy_envoy_internal_host_port }}:{{ proxy_envoy_internal_container_port }}/tcp"
  - "{{ proxy_envoy_admin_host_port }}:{{ proxy_envoy_admin_container_port }}/tcp"
```

#### Examples of IP Address Violations

**❌ FORBIDDEN - Hardcoded IP addresses:**
```yaml
ansible_host: 127.0.0.1
docker_network_gateway: "172.26.0.1"
bindaddress: 0.0.0.0
```

**✅ REQUIRED - All IPs as variables:**
```yaml
ansible_host: "{{ ansible_host_ip }}"
docker_network_gateway: "{{ docker_network_gateway }}"
bindaddress: "{{ service_bind_address }}"
```

#### Rationale

- **Portability**: Variables allow easy deployment across different environments
- **Flexibility**: Changes can be made in one place (group_vars, .env files) without touching configuration files
- **Security**: Sensitive network topology details can be externalized
- **Maintainability**: Centralized configuration management

#### Enforcement

All new configuration must:
1. Define all ports as variables in `group_vars/all.yml` or service-specific `.env` files
2. Define all IP addresses as variables, including:
   - Network gateways and subnets
   - Service bind addresses (use variables instead of `0.0.0.0` or `127.0.0.1`)
   - Container IP assignments
3. Never hardcode port numbers in `ports:` sections (both host and container ports must be variables)
4. Never hardcode IP addresses in any configuration file

#### Current Violations to Fix

The following files contain hardcoded ports or IPs and need to be refactored:

**Ansible Tasks:**
- `shared/active/02-config/ansible/roles/vpn/tasks/main.yml` (lines 40-45)
- `shared/active/02-config/ansible/roles/proxy/tasks/main.yml` (lines 138-141 - container ports)

**Docker Compose Files:**
- `shared/active/03-container/services/vpn/docker-compose.vpn.yml` (lines 20-25)
- `shared/active/03-container/services/dns/adguard/docker-compose.adguard.yml` (lines 14-16)
- Various other docker-compose files with hardcoded ports

When working on localnet, always check for hardcoded IPs and ports before committing changes.

## Deployment Workflow Rule

**MANDATORY DEPLOYMENT PROCESS**: When making changes to any deployments (Ansible playbooks, Docker containers, configurations), you MUST follow this workflow:

### Step 0: Change Impact Analysis (FIRST STEP)

**ALWAYS start by analyzing the change impact** before any other work:

1. **Determine if the change impacts deployment**:
   - **Build-impacting changes**: Dockerfile changes, Ansible role changes, docker-compose changes, code changes that require rebuilding
   - **Non-build changes**: Documentation, comments, configuration files that don't require deployment, README updates

2. **If NON-BUILD change**: Skip deployment options, proceed directly to lint/tests only
   - Run linting appropriate to the file type
   - Run any available tests
   - Complete without deployment steps

3. **If BUILD-IMPACTING change**: Ask deployment intent upfront
   - **Ask the user**: "This change requires deployment. How should I proceed?"
   - **Option A**: "Lint, build, tests without deployment, deploy and test locally, then deploy and test remotely" (only if remote deployment exists)
   - **Option B**: "Lint, build, tests without deployment, deploy and test locally"
   - **Option C**: "Lint, build, tests without deployment only"

4. **Wait for user response** before proceeding with any deployment work

5. **Execute the entire chosen path without further interruptions**

### Standard Deployment Workflow

#### Path A: Full Deployment Pipeline (Local + Remote)

**Only offered when remote deployment component exists**

1. **Lint Changes**: Run appropriate linting/validation for the changes
   - Ansible: `devbox run -- rtk ansible-lint` or `devbox run -- rtk ansible-syntax`
   - Docker: Validate Dockerfile syntax and docker-compose files
   - Configuration: Check YAML syntax and variable references

2. **Build**: Build the artifacts (Docker images, packages, etc.)
   - Docker: `docker build` or `docker-compose build`
   - Ansible: No build step, but validate role syntax
   - Other: Run appropriate build commands

3. **Tests Without Deployment**: Run tests that don't require deployment
   - Unit tests
   - Linting checks
   - Static analysis
   - Code validation

4. **Deploy Locally**: Deploy changes to a local test environment
   - Use local test infrastructure (docker-compose test environment, local VM, etc.)
   - Verify the deployment completes without errors
   - Check logs for any warnings or issues

5. **Test Locally**: Verify the changes work correctly in the local environment
   - Run functional tests specific to the changes
   - Verify service health and connectivity
   - Test the specific functionality that was changed
   - Check for regressions in existing functionality

6. **Deploy Remotely**: Deploy to the final destination
   - Deploy to the final destination (OCI Cloud Server, production environment, etc.)
   - Use appropriate deployment playbooks/commands
   - Monitor deployment for errors

7. **Test Remotely**: Verify the changes work correctly in the remote environment
   - Run the same tests that were run locally
   - Verify service health in the remote environment
   - Check logs for any issues specific to the remote deployment
   - Document any differences between local and remote behavior

8. **Provide Connection Summary**: Always provide connection and testing information
   - Include how to connect to the deployment remotely
   - Include how to test the deployment yourself
   - Provide specific commands and verification steps
   - Include relevant ports, IPs, authentication details

#### Path B: Local Deployment Only

1. **Lint Changes**: Run appropriate linting/validation for the changes
   - Ansible: `devbox run -- rtk ansible-lint` or `devbox run -- rtk ansible-syntax`
   - Docker: Validate Dockerfile syntax and docker-compose files
   - Configuration: Check YAML syntax and variable references

2. **Build**: Build the artifacts (Docker images, packages, etc.)
   - Docker: `docker build` or `docker-compose build`
   - Ansible: No build step, but validate role syntax
   - Other: Run appropriate build commands

3. **Tests Without Deployment**: Run tests that don't require deployment
   - Unit tests
   - Linting checks
   - Static analysis
   - Code validation

4. **Deploy Locally**: Deploy changes to a local test environment
   - Use local test infrastructure (docker-compose test environment, local VM, etc.)
   - Verify the deployment completes without errors
   - Check logs for any warnings or issues

5. **Test Locally**: Verify the changes work correctly in the local environment
   - Run functional tests specific to the changes
   - Verify service health and connectivity
   - Test the specific functionality that was changed
   - Check for regressions in existing functionality

6. **Provide Local Connection Summary**: Provide connection and testing information for local deployment
   - Include how to connect to the local deployment
   - Include how to test the deployment yourself
   - Provide specific commands and verification steps
   - Include relevant ports, IPs, authentication details

#### Path C: Lint, Build, and Test Only (No Deployment)

1. **Lint Changes**: Run appropriate linting/validation for the changes
   - Ansible: `devbox run -- rtk ansible-lint` or `devbox run -- rtk ansible-syntax`
   - Docker: Validate Dockerfile syntax and docker-compose files
   - Configuration: Check YAML syntax and variable references

2. **Build**: Build the artifacts (Docker images, packages, etc.)
   - Docker: `docker build` or `docker-compose build`
   - Ansible: No build step, but validate role syntax
   - Other: Run appropriate build commands

3. **Tests Without Deployment**: Run tests that don't require deployment
   - Unit tests
   - Linting checks
   - Static analysis
   - Code validation

4. **Provide Summary**: Summary of lint, build, and test results
   - Report any issues found
   - Confirm readiness for deployment (if applicable)

#### Path D: Non-Build Changes (Documentation, Comments, etc.)

1. **Lint Changes**: Run appropriate linting/validation for the changes
   - Markdown linting for documentation
   - YAML syntax for config files
   - Spell checking for documentation

2. **Complete**: No deployment or testing required
   - Confirm changes are syntactically correct
   - No further action needed

### Exceptions

**The change impact analysis and deployment options can be skipped ONLY when:**
- User explicitly provides clear deployment instructions in the original request
- Changes are clearly non-build impacting (documentation, comments only)
- The context makes deployment intent obvious (e.g., fixing a critical production issue with explicit deployment instruction)

**Examples of clear instructions that skip the analysis:**
- "Deploy this directly to OCI and test it" → Skip to Path A (Full Pipeline)
- "Just update the README" → Skip to Path D (Non-Build Changes)
- "This is a production hotfix, deploy immediately to OCI" → Skip to Path A (Full Pipeline)
- "Test this locally only" → Skip to Path B (Local Deployment Only)

**When in doubt, ALWAYS perform the change impact analysis first.**

### Verification Requirements

**For Path A (Full Deployment Pipeline):**
- [ ] Linting passes without errors or warnings
- [ ] Build succeeds without errors
- [ ] Tests without deployment pass
- [ ] Local deployment succeeds without errors
- [ ] Local tests pass and functionality is verified
- [ ] Remote deployment succeeds without errors
- [ ] Remote tests pass and functionality is verified
- [ ] No regressions introduced in existing functionality
- [ ] Connection summary provided with remote access details
- [ ] Testing instructions provided for user verification

**For Path B (Local Deployment Only):**
- [ ] Linting passes without errors or warnings
- [ ] Build succeeds without errors
- [ ] Tests without deployment pass
- [ ] Local deployment succeeds without errors
- [ ] Local tests pass and functionality is verified
- [ ] No regressions introduced in existing functionality
- [ ] Local connection summary provided
- [ ] Local testing instructions provided

**For Path C (Lint, Build, Test Only):**
- [ ] Linting passes without errors or warnings
- [ ] Build succeeds without errors
- [ ] Tests without deployment pass
- [ ] Summary of results provided
- [ ] No deployment performed (as requested)

**For Path D (Non-Build Changes):**
- [ ] Linting passes without errors or warnings
- [ ] Changes are syntactically correct
- [ ] No build or deployment required
- [ ] Summary of changes provided

### Failure Handling

If any step fails:
1. **Stop** the deployment workflow
2. **Diagnose** the root cause of the failure
3. **Fix** the issue
4. **Restart** from the failed step
5. **Document** the issue and resolution

### Example Commands

**Initial Analysis (Always First):**
```
"Analyzing change impact... This change requires deployment. How should I proceed?
A) Lint, build, tests without deployment, deploy and test locally, then deploy and test remotely
B) Lint, build, tests without deployment, deploy and test locally
C) Lint, build, tests without deployment only"
```

**For Docker changes (Path A - Full Pipeline):**
```bash
# 1. Lint
devbox run -- rtk ansible-lint
devbox run -- rtk ansible-syntax playbook.yml

# 2. Deploy locally
devbox run -- rtk ansible-playbook -i test_inventory.yml playbook.yml

# 3. Test locally
# Run specific tests for the changes

# 4. Deploy remotely (per user's initial choice)
devbox run -- rtk ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml playbook.yml --vault-password-file ~/.ansible/vault_password

# 5. Test remotely
# Run the same tests that were run locally

# 6. Provide connection summary
"Deployment completed successfully. Here's how to connect and test:

**Remote Connection:**
- SSH: ssh cuser@<oci-server-ip>
- Container: docker exec -it <container-name> sh
- Tailscale: ssh cuser@<tailscale-ip>

**Testing Commands:**
- Check status: docker ps
- View logs: docker logs <container-name>
- Test functionality: <specific test commands>
- Verify health: <health check commands>

**Key Details:**
- Ports: <port mappings>
- Volumes: <volume mounts>
- Environment: <relevant env vars>"

**For Ansible changes (Path B - Local Deployment Only):**
```bash
# 1. Lint
docker build --no-cache -f Dockerfile .
docker-compose config

# 2. Deploy remotely (skip local testing)
# Use appropriate deployment method (Ansible, docker-compose, etc.)

# 3. Test remotely
# Verify remote deployment

# 4. Provide connection summary
"Deployment completed successfully. Here's how to connect and test:

**Remote Connection:**
- SSH: ssh cuser@<oci-server-ip>
- Container: docker exec -it <container-name> sh
- Service URL: http://<service-url>:<port>

**Testing Commands:**
- Check status: docker ps
- View logs: docker logs <container-name>
- Test functionality: curl http://<service-url>:<port>/endpoint
- Verify health: <health check commands>

**Key Details:**
- Ports: <port mappings>
- Volumes: <volume mounts>
- Environment: <relevant env vars>"

This workflow ensures changes are properly validated before reaching production environments and prevents breaking deployments.

**Additional Examples:**

**For Docker changes (Path A - Full Pipeline):**
```bash
# 1. Lint
docker build --no-cache -f Dockerfile .
docker-compose config

# 2. Build
docker build -t <image-name> .

# 3. Tests without deployment
# Run unit tests, static analysis, etc.

# 4. Deploy locally
docker-compose -f docker-compose.test.yml up -d --build

# 5. Test locally
docker logs <container-name>
# Run functional tests

# 6. Deploy remotely
# Use appropriate deployment method (Ansible, docker-compose, etc.)

# 7. Test remotely
# Verify remote deployment
# Run the same tests that were run locally

# 8. Provide connection summary
"Deployment completed successfully. Here's how to connect and test:

**Remote Connection:**
- SSH: ssh cuser@<oci-server-ip>
- Container: docker exec -it <container-name> sh
- Service URL: http://<service-url>:<port>

**Testing Commands:**
- Check status: docker ps
- View logs: docker logs <container-name>
- Test functionality: curl http://<service-url>:<port>/endpoint
- Verify health: <health check commands>

**Key Details:**
- Ports: <port mappings>
- Volumes: <volume mounts>
- Environment: <relevant env vars>"
```

**For documentation changes (Path D - Non-Build Changes):**
```bash
# 1. Lint
# Markdown linting, spell checking, etc.

# 2. Complete
# No build or deployment required

# Summary
"Documentation changes completed successfully. No deployment required."
```

### Connection Summary Format

The connection summary must include:

**Required Elements:**
1. **Connection Methods**: All ways to connect to the deployment (SSH, Tailscale, direct access, etc.)
2. **Authentication**: Required credentials, keys, or authentication methods
3. **Network Details**: IPs, ports, hostnames, URLs
4. **Testing Commands**: Specific commands to test the deployment
5. **Health Checks**: How to verify the deployment is healthy
6. **Key Configuration**: Relevant environment variables, volumes, or settings

**Example Template:**
```markdown
**Deployment Summary:** [Service Name] deployed to [Destination]

**Remote Connection Options:**
1. **Direct SSH:** `ssh -i ~/.ssh/key user@<ip-address>`
2. **Tailscale:** `ssh user@<tailscale-ip>` or `tailscale ssh user@<hostname>`
3. **Container Access:** `docker exec -it <container-name> zsh`
4. **Web Interface:** `https://<service-url>:<port>`

**Authentication:**
- SSH Key: `~/.ssh/<key-name>`
- Username: `cuser`
- Password: (key-based auth only)
- Tokens: (if applicable)

**Testing Commands:**
```bash
# Check service status
docker ps | grep <service-name>

# View recent logs
docker logs <service-name> --tail=50

# Test specific functionality
<specific test command>

# Health check
curl http://<health-check-endpoint>
```

**Key Details:**
- **Ports:** <host-port>:<container-port>
- **Volumes:** <volume mappings>
- **Network:** <network name>
- **Environment:** <key env vars>
- **Documentation:** <link to relevant docs>
```

**Important Notes:**
- Provide the connection summary **even if** remote testing was already completed
- Make the summary actionable and specific to the deployment
- Include both connection methods AND verification steps
- Tailor the information to the specific service being deployed
- Reference relevant documentation for complex deployments

## Repository Structure

This repository uses a two-tier hierarchy at the root:

```text
infrahub/
  shared/active/          # Reusable infrastructure code (roles graduate to levonk Galaxy namespace)
    00-os/
    01-build/
    02-config/ansible/    # Shared roles, playbooks, templates
    03-container/         # Docker compose files, container configs
    04-deploy/
    05-gitops/
    06-provision/
    07-local/
    08-docs/

  <client>/active/        # Client-specific overrides (inventories, host_vars, secrets)
    02-config/ansible/
      inventories/
      host_vars/
      group_vars/
```

- **`shared/active/`** contains all reusable roles, playbooks, and container definitions. Roles here are the source of truth that may graduate to the `levonk` namespace on Ansible Galaxy.
- **Client directories** (e.g., `levonk/`, `client-acme/`) contain only client-specific data: inventories, host variables, group variables, and vaulted secrets. They never contain roles or playbooks.

## Ansible Architecture

### Separation of Concerns

| Layer | Location | Rule |
|-------|----------|------|
| **Roles** | `shared/active/02-config/ansible/roles/` | Reusable, pure, parameterized. No client data. |
| **Playbooks** | `shared/active/02-config/ansible/playbooks/` | Stack blueprints. Import roles, select hosts. |
| **Inventories** | `<client>/active/02-config/ansible/inventories/` | Hosts, groups, which stacks go where. |
| **Variables** | `<client>/active/02-config/ansible/group_vars/` + `host_vars/` | Client-specific IPs, ports, secrets, feature flags. |

**Critical rule**: Playbooks live in `shared/`. Inventories and vars live in client directories. A playbook references its inventory at runtime via `-i`.

### Role Naming Convention

All roles in `shared/` must use **functional-group prefixes** to keep the directory scannable:

```text
roles/
  common/                 # Unprefixed — cross-cutting infrastructure
  docker-host/

  vpn-netbird/            # One role per VPN provider
  vpn-tailscale/
  vpn-wireguard/
  vpn-gluetun/
  vpn-twingate/
  vpn-tor/

  dns-adguard/
  dns-coredns/
  dns-dnsdist/

  proxy-traefik/
  proxy-envoy/
  proxy-squid/
  proxy-privoxy/
  proxy-crowdsec/
  proxy-authelia/
```

**Why**: With 15+ roles, flat naming is unmaintainable. Prefixes cluster related roles and prevent collisions (e.g., `netbird` could mean the SaaS, client, or control plane).

**Do not** create separate roles for sub-components of a single provider. `vpn-netbird/` should include management, signal, relay, and gateway-agent tasks as internal includes, not as `netbird-mgmt-service/`, `netbird-signal-service/`, etc.

**Why not subdirectories?** Ansible's role loader resolves `roles/<name>/` directly under `roles_path`. `roles/dns/adguard/` is not discoverable as role `adguard` by default. Prefixing (`dns-adguard/`) is the only way to cluster related roles while keeping them valid Ansible roles.

### Playbook Structure

Playbooks are stack blueprints. Each targets a functional group defined in the inventory:

```yaml
# shared/active/02-config/ansible/playbooks/stacks/baseline.yml
- name: "Deploy Baseline"
  hosts: baseline_servers
  become: true
  roles:
    - common
    - docker-host
```

The site playbook imports stacks:

```yaml
# shared/active/02-config/ansible/playbooks/site.yml
- import_playbook: stacks/baseline.yml
- import_playbook: stacks/docker-host.yml
- import_playbook: stacks/dns.yml
- import_playbook: stacks/proxy.yml
- import_playbook: stacks/vpn.yml
```

**Do not** put `when: dns_stack_enabled` boolean flags in playbooks. Use inventory group membership instead:

```yaml
# client/levonk/active/02-config/ansible/inventories/localnet.yml
all:
  children:
    baseline_servers:
      hosts:
        cloud-primary:
    dns_servers:
      children:
        baseline_servers:
    proxy_servers:
      children:
        baseline_servers:
```

### Variable Scoping

1. **Role defaults** (`roles/<role>/defaults/main.yml`): Neutral, overridable defaults. Must not reference `localnet_*` paths.
2. **Client group_vars** (`<client>/group_vars/all.yml`): Client-specific overrides (IPs, ports, feature flags).
3. **Client host_vars** (`<client>/host_vars/<host>.yml`): Host-specific overrides.
4. **Vaulted secrets** (`<client>/group_vars/all.vault`): Encrypted secrets. Never in `shared/`.

**No `group_vars/all.yml` in `shared/`**. All variable data is client-scoped.

## Ansible Galaxy Collection Strategy

### Long-Term Goal

Reusable roles in `shared/` graduate to collections in the `levonk` namespace. Collections are developed and versioned within this repo, then published to Ansible Galaxy:

```text
infrahub/
  shared/active/02-config/ansible/
    roles/              # Stage 1 & 2: roles under active development
    collections/        # Stage 3+: collections ready for Galaxy
      ansible_collections/
        levonk/
          vpn/
            galaxy.yml
            roles/
            playbooks/
          proxy/
            galaxy.yml
            roles/
    playbooks/
    inventories/
  <client>/active/02-config/ansible/
    inventories/
    host_vars/
    group_vars/
```

### Collection Development Path

Collections are developed in-tree under `shared/active/02-config/ansible/collections/`, already wired in `ansible.cfg`:

```ini
# shared/active/02-config/ansible/ansible.cfg
collections_paths = collections
```

For a collection to be recognized by Ansible, it must follow the strict FQCN hierarchy:

```text
collections/
  ansible_collections/
    levonk/
      vpn/
        galaxy.yml
        roles/
        playbooks/
      proxy/
        galaxy.yml
        roles/
```

**The `ansible_collections/<namespace>/<collection>/` path is mandatory.** You cannot flatten this or use arbitrary directory names. Ansible resolves `levonk.vpn.netbird` by walking `ansible_collections/levonk/vpn/roles/netbird/`.

### When to Promote to Collection

**Do not** move a role into `collections/` until it is:
- Free of client-specific defaults (no `localnet_*` paths, no hardcoded IPs)
- Stable (no changes for 2-3 weeks)
- Tested against at least two clients

### Migration Path

1. **Stage 1**: Local prefixed role in `shared/active/02-config/ansible/roles/vpn-netbird/`
2. **Stage 2**: Genericize defaults, remove localnet-specific paths
3. **Stage 3**: Move to `shared/active/02-config/ansible/collections/ansible_collections/levonk/vpn/roles/netbird/`
4. **Stage 4**: Publish to Galaxy, consume in this repo via `requirements.yml`:

```yaml
# <client>/active/02-config/ansible/requirements.yml
collections:
  - name: levonk.vpn
    source: https://galaxy.ansible.com
```

### Client Namespaces

If a client needs a custom role that is not suitable for the public `levonk` namespace:
- Keep it in `shared/active/02-config/ansible/roles/` with a `client-<name>-` prefix (e.g., `client-acme-auth/`)
- Or create a private Galaxy collection under the client's own namespace

## Small Business Profiles

Common deployment profiles for client onboarding:

| Profile | Stacks | Services |
|---------|--------|----------|
| `minimal-cloud` | baseline, docker-host, dns, proxy | SSH hardening, DNS, reverse proxy |
| `secure-remote` | minimal-cloud + vpn | + WireGuard / Tailscale |
| `full-mesh` | secure-remote + netbird-control | + Netbird control plane |

Profiles are expressed as group membership in the client's inventory, not as playbook conditionals.
