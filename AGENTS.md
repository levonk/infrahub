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

### Vault Edits (Agent → User Handoff)

**CRITICAL**: When the agent needs a secret added/changed in the vault, the agent MUST NOT attempt to edit the vault file directly. Instead, the agent MUST provide the user with a single **copyable** `docker run` command that opens an interactive `ansible-vault edit` session with the correct paths pre-filled.

**Why a Docker container?** The vault file is encrypted on disk and `ansible-vault edit` requires an interactive TTY with `ansible-vault` installed. A Docker container guarantees the tool is available, the vault password file is mounted read-only, and the vault file is mounted read-write — without requiring the user to install anything or remember paths.

**Template** (agent fills in `<SECRET_NAME>` and `<SECRET_VALUE>` in the instructions, the user runs the command):

```bash
docker run --rm -it \
  -v "$HOME/.ansible/vault_password:/vault_password:ro" \
  -v "$HOME/p/gh/levonk/infrahub/levonk/active/02-config/ansible/inventories/group_vars:/vault-dir" \
  -e EDITOR=vi \
  alpine/ansible:latest \
  ansible-vault edit /vault-dir/infrahub-levonk-all.vault.yml --vault-password-file /vault_password
```

> **Why mount the directory, not the file?** `ansible-vault edit` writes to a temp file then atomically replaces the original via `os.remove()` + rename. Docker file bind mounts can't be removed from inside the container (`Errno 16: Resource busy`). Mounting the directory lets the atomic replace work normally.

**Agent workflow when a new secret is needed:**
1. Generate the secret value (e.g., `openssl rand -hex 32`)
2. Provide the user with:
   - The exact YAML line(s) to add (e.g., `vault_langfuse_postgres_password: "abc123..."`)
   - The copyable `docker run` command above (paths already filled in)
3. Tell the user: "Run this command, add the line(s) I listed, save and exit"
4. Wait for the user to confirm before proceeding with deployment

**NEVER**:
- ❌ Run `ansible-vault edit` yourself (no interactive TTY in the agent shell)
- ❌ Decrypt → edit → re-encrypt manually (corruption risk, see Vault Troubleshooting)
- ❌ Store secrets in plaintext files while waiting for the user
- ❌ Print the secret value in the conversation after the user adds it

### Vault Troubleshooting

**Vault Corruption Issues:**
If you encounter "Vault format unhexlify error: Odd-length string" or similar vault decryption errors:

1. **Check git history for working versions:**
   ```bash
   cd levonk
   git log --oneline --all -- active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml
   ```

2. **Restore from a known good commit:**
   ```bash
   git show <commit-hash>:active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml > /tmp/working-vault.yml
   cp /tmp/working-vault.yml active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml
   ```

3. **Verify vault accessibility:**
   ```bash
   devbox run -- ansible-vault view levonk/active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml \
     --vault-password-file ~/.ansible/vault_password
   ```

4. **Common vault issues:**
   - **Odd-length hex strings**: File was corrupted during creation/editing
   - **Mixed format**: File contains both encrypted content and inline encrypted values
   - **Wrong password**: Vault password file doesn't match the encryption key
   - **Version mismatch**: Ansible version incompatibility with vault format

### CRITICAL: Secret/Key Handling Policy

**NEVER** share API keys, passwords, tokens, or any secret/private information in open communication unless explicitly requested by the user.

**Secret Storage Strategy:**
This project follows a hybrid secret storage approach as defined in [ADR-20260624001: Hybrid Sensitive Information Storage Strategy](shared/active/08-docs/adr/adr-20260624001-hybrid-sensitive-information-storage.md). Key principles:

- **Per-Client Central Vault**: All shared secrets stored in client-specific vault files (e.g., `levonk/active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml`)
- **Shared Path Clean**: The `shared/` directory must NEVER contain sensitive information
- **In-Service Transient Secrets**: Service-specific transient secrets (JWT tokens, session keys) stored within service configurations
- **Ansible Variable Distribution**: Use Ansible vault variables for secure distribution at runtime

### Infrastructure Consolidation Strategy

**Infrastructure Topology Management:**
This project follows a hybrid infrastructure consolidation approach as defined in [ADR-20260625001: Infrastructure Consolidation Strategy](shared/active/08-docs/adr/adr-20260625001-infrastructure-consolidation.md). Key principles:

- **Centralized Schemas**: Shared infrastructure variable schemas in `shared/active/02-config/ansible/infrastructure/`
- **Client-Specific Values**: Client infrastructure value overrides in `levonk/active/02-config/ansible/infrastructure/`
- **Single Source of Truth**: All IP addresses, ports, domain names, and storage paths consolidated
- **Variable References**: Configuration files reference consolidated infrastructure variables

**Infrastructure Categories:**
- `networks.yml` - Network topology (subnets, gateways, network names, IP allocations)
- `ports.yml` - Port allocations (host/container ports by service)
- `domains.yml` - Domain names, DNS records, and hostnames
- `storage.yml` - Storage paths, volumes, and container mounts

**Variable Naming Convention:**
- Pattern: `infra_{CATEGORY}_{SERVICE}_{CONTEXT}_{ATTRIBUTE}`
- Examples: `infra_network_vpn_nordvpn_subnet`, `infra_port_ai_forge_host`, `infra_domain_ai_dashboard_web`

**When Adding New Infrastructure:**
1. **ALWAYS** check existing infrastructure files for conflicts before adding new ports/IPs
2. **ALWAYS** use consolidated infrastructure variables instead of hardcoded values
3. **ALWAYS** follow the `infra_` naming convention for new infrastructure variables
4. **NEVER** hardcode IP addresses, ports, or domain names in playbooks or configuration files
5. **NEVER** add infrastructure variables to regular group_vars/host_vars files

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
devbox run -- ansible-vault view ~/p/gh/levonk/infrahub/levonk/active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml --vault-password-file ~/.ansible/vault_password
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

## CRITICAL: Submodule Handling Rules

**NEVER** convert git submodules to regular directories. This destroys the intended architecture and can expose sensitive information.

### Submodule Workflow

**When working with client submodules (e.g., levonk/):**

1. **NEVER** delete the submodule and replace it with a regular directory
2. **NEVER** treat submodule files as if they were part of the parent repo
3. **ALWAYS** use proper git submodule commands:
   ```bash
   # Update submodule to latest
   git submodule update --remote levonk
   
   # Enter submodule to make changes
   cd levonk
   # Make changes, commit, push
   git add .
   git commit -m "Description"
   git push origin master
   
   # Return to parent and update reference
   cd ..
   git add levonk
   git commit -m "Update levonk submodule reference"
   ```

4. **ALWAYS** work within the submodule directory for submodule-specific changes
5. **NEVER** modify submodule files from the parent repo without entering the submodule first

### Client Submodule Security

**CRITICAL**: Client submodules contain PRIVATE CLIENT-SPECIFIC INFORMATION:

- **✅ CORRECT**: Secrets in `levonk/active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml`
- **❌ FORBIDDEN**: Secrets in parent repo's `shared/` directory
- **❌ FORBIDDEN**: Converting submodule to regular directory (breaks isolation)
- **❌ FORBIDDEN**: Moving secrets from submodule to shared/ directory

Each client submodule has its own `AGENTS.md` with specific rules. Always read the submodule's AGENTS.md before making changes.

### Detection of Submodule Issues

**WARNING SIGNS** that a submodule has been incorrectly converted:
- Submodule directory contains `.gitignore` file (shouldn't exist in submodule)
- `git status` shows submodule as "modified" with no staged changes
- Submodule files appear as regular files instead of submodule reference
- `.gitmodules` file has been modified to remove submodule entry

**IMMEDIATE REMEDIATION** if detected:
1. Revert the destructive commit
2. Restore proper git submodule structure
3. Commit the fix immediately
4. Review for any exposed sensitive information

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

### DNS Record Management (Cloudflare)

**MANDATORY**: DNS records for all services exposed via Traefik MUST be created automatically by the Ansible Cloudflare DNS playbook. **NEVER** create DNS records manually in the Cloudflare dashboard — that's why the vault contains `vault_cloudflare_api_token` and `vault_cloudflare_zone_id`.

The DNS architecture has two layers — see [Architectural Invariant #9](#9-cloudflare-dns-uses-cnames-to-tailscale-fqdns--never-a-records-to-tailscale-ips) for the CNAME rule and [Cloudflare DDNS](#cloudflare-ddns-public-ip-redundancy) for the DDNS layer.

**Playbook**: `shared/active/02-config/ansible/playbooks/configure-cloudflare-dns.yml`
**Role**: `shared/active/02-config/ansible/roles/cloudflare-dns/`

**When deploying a new service with a public domain:**
1. Add the DNS record to the `cloudflare_dns_records` list in the playbook
2. Run the DNS playbook before (or as part of) the service deployment
3. The role is idempotent — it creates missing records, updates changed records, and skips matching records
4. The role handles A→CNAME migration automatically (deletes conflicting A records before creating CNAMEs)

```bash
# Run DNS configuration (creates/updates all records in cloudflare_dns_records)
devbox run -- rtk ansible-playbook shared/active/02-config/ansible/playbooks/configure-cloudflare-dns.yml \
  --vault-password-file ~/.ansible/vault_password
```

**Adding a new DNS record:**
```yaml
# In shared/active/02-config/ansible/playbooks/configure-cloudflare-dns.yml
cloudflare_dns_records:
  - name: "new-service.levonk.com"
    type: "CNAME"
    content: "{{ infra_tailscale_fqdn_cloud_server | default('oci.tale-grouper.ts.net') }}"
    ttl: "{{ cloudflare_dns_ttl }}"
    proxied: "{{ cloudflare_dns_proxied }}"
    state: "{{ cloudflare_dns_state }}"
```

**Vault requirements** (in `levonk/active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml`):
- `vault_cloudflare_api_token` — valid Cloudflare API token with DNS edit permissions for the zone
- `vault_cloudflare_zone_id` — Cloudflare zone ID for `levonk.com`

**If the DNS playbook fails with 401 "Authentication error"**: the `vault_cloudflare_api_token` in the vault is invalid or expired. Generate a new token at https://dash.cloudflare.com/profile/api-tokens (use "Edit zone DNS" template, scoped to the `levonk.com` zone) and update the vault. Do NOT work around this by creating records manually.

### Cloudflare DDNS (Public IP Redundancy)

The `cloudflare-ddns` role deploys a lightweight container on each Tailscale-attached host that updates a Cloudflare A record (`{hostname}.mach.{domain}`) with the host's **public IP** every 5 minutes. This provides a non-Tailscale fallback path — if Tailscale MagicDNS is down but the host still has internet, the `*.mach.levonk.com` records resolve to the public IP.

**Playbook**: `shared/active/02-config/ansible/playbooks/deploy-cloudflare-ddns.yml`
**Role**: `shared/active/02-config/ansible/roles/cloudflare-ddns/`

**Two-layer DNS architecture:**

| Layer | Record type | Target | Purpose |
|-------|------------|--------|---------|
| `*.levonk.com` | CNAME | `*.tale-grouper.ts.net` (Tailscale FQDN) | Primary access via Tailscale |
| `*.mach.levonk.com` | A | Public IP (auto-updated) | Fallback when Tailscale DNS is down |

**Deploying DDNS to a new host:**
1. Set `cloudflare_ddns_hostname` in the host's inventory vars (e.g., `"oci"`, `"kckinai"`)
2. Run the playbook targeting that host
3. The container detects the public IP via external services (`api.ipify.org`, `ifconfig.me`, `icanhazip.com`) and creates/updates the A record

```bash
# Deploy DDNS to all Tailscale-attached hosts
devbox run -- ansible-playbook \
  -i levonk/active/02-config/ansible/inventories/oci.yml \
  -i levonk/active/02-config/ansible/inventories/localnet.yml \
  shared/active/02-config/ansible/playbooks/deploy-cloudflare-ddns.yml \
  --vault-password-file ~/.ansible/vault_password
```

**Clients using this feature**: levonk (hosts: `oci`, `kckinai`)

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

### Developer Guide

For workflows, the critical-files directory tree (what NOT to replicate), code patterns, boundaries, and known gotchas, see [`.agents/knowledge/developer.md`](.agents/knowledge/developer.md). That guide documents:

- **Critical files tree** — the single-source-of-truth files for vault, infrastructure values (domains, networks, ports, storage), Dockerfiles, and external config (vault password, Docker daemon, SSH keys)
- **Do-not-rePLICATE rules** — which files must never be duplicated or have values copied into roles/playbooks/group_vars
- **Known gotchas** — disk space, Traefik Docker provider, ACME staging, build caching, healthcheck formats, handler state

## Ansible Architecture

### Separation of Concerns

| Layer | Location | Rule |
|-------|----------|------|
| **Roles** | `shared/active/02-config/ansible/roles/` | Reusable, pure, parameterized. No client data. |
| **Playbooks** | `shared/active/02-config/ansible/playbooks/` | Stack blueprints. Import roles, select hosts. |
| **Inventories** | `<client>/active/02-config/ansible/inventories/` | Hosts, groups, which stacks go where. |
| **Variables** | `<client>/active/02-config/ansible/inventories/group_vars/` + `host_vars/` | Client-specific IPs, ports, secrets, feature flags. |

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
4. **Vaulted secrets** (`<client>/group_vars/infrahub-<client>-all.vault.yml`): Encrypted secrets. Never in `shared/`.

**No `group_vars/all.yml` in `shared/`**. All variable data is client-scoped.

### Architectural Invariants

These rules are non-negotiable. Violations indicate a design error, not a style choice.

#### 1. `shared/` is client-agnostic

Nothing under `shared/` may reference a specific client — not by name, not by hardcoded value, not by implication. `shared/` holds reusable roles, playbooks, templates, container definitions, infrastructure schemas, and docs. Every client-specific detail (IPs, ports, domains, storage paths, secrets, hostnames, feature flags) lives in the client directory (`<client>/active/...`) and is injected at runtime via inventory and group_vars.

If a playbook or role in `shared/` only makes sense for one client, it is in the wrong place. Either generalize it (parameterize the client-specific bits) or move it into the client directory.

**This includes Jinja2 template defaults.** A `default()` filter in a shared template must NOT contain a client-specific value. For example, `{{ domain | default('start.levonk.com') }}` is a violation — `start.levonk.com` is client-specific. Use an empty default (`default('')`) or a generic placeholder, and require the client host_vars/infrastructure files to provide the actual value. Templates should be variable-driven skeletons; the data comes from the client directory.

#### 2. Build before deploy — on the control machine, NEVER on the target

The workflow is: **build → test locally → push to registry → deploy (pull from registry)**. Builds happen on the local command-and-control machine (the operator's Mac), NEVER on the target host. Shared build artifacts (container images, binaries) are produced locally, validated locally, pushed to the local Docker registry, and only then pulled by client machines for deployment.

**The local Docker registry** is deployed on the OCI cloud server via `shared/active/02-config/ansible/playbooks/deploy-local-registry.yml` at `http://<cloud-server-tailscale-ip>:5000` (port `infra_port_registry_host`). It is accessible over Tailscale (HTTP-only, Tailscale encrypts the transport). All locally-built images are tagged as `<registry>/<image>:<tag>` and pushed there. Deployment roles use `community.docker.docker_image` with `source: pull` to fetch them on the target.

**Build workflow for a locally-built image:**
1. On the Mac: `docker build -t <registry>/<image>:<tag> -f <dockerfile> <context>`
2. On the Mac: `docker push <registry>/<image>:<tag>`
3. In the Ansible role: `community.docker.docker_image` with `source: pull`, `name: "<registry>/<image>:<tag>"`
4. In the Ansible role: `community.docker.docker_container` with `image: "<registry>/<image>:<tag>"`

**NEVER build on the target host:**
- ❌ `community.docker.docker_image` with `source: build` in a role that runs against a target host — this builds ON the target, exhausting its disk and violating this rule
- ❌ Copying a build context (Dockerfile, assets) to the target and building there
- ❌ `ansible.builtin.shell: docker build ...` on the target

**The ONLY exception** is a documented, client-specific reason that justifies building on the target (e.g., a toolchain that cannot cross-compile) — and that exception must be called out in the playbook with a `# BUILD-ON-TARGET JUSTIFIED:` comment explaining why.

**Why this matters**: Target hosts (like the OCI cloud server) often have small disks (30G). Building Docker images on them fills the disk with build layers, cache, and intermediate images, causing cascading failures across all services. Building on the control machine (which has more disk and is rebuildable) and shipping via registry keeps targets thin, builds reproducible, and the control machine the single source of truth for what gets deployed.

**Multi-stage builds are mandatory** when an image has build dependencies (pip, npm, cargo, apt build-essential, etc.) that aren't needed at runtime. The builder stage installs compilers and build tools; the runtime stage copies only the compiled artifacts and runtime dependencies. This keeps the final image small — which matters because the target pulls it from the registry. Images that only add runtime packages to an existing base image (e.g. `RUN apk add curl` on an official image) are the only exception. The build machine (Mac) handles the intermediate builder layers; they never reach the target.

**If a role currently uses `source: build` and runs against a target**: That role is broken by design. Refactor it to: (1) build on the Mac via a justfile target or local script, (2) push to the local registry, (3) change the role to `source: pull`. The build context copy task (`ansible.builtin.copy` of Dockerfile/assets to target) should be removed — it is only needed for target-side builds.

#### 3. POSIX paths everywhere — except Windows host setup

All paths in `shared/` playbooks, roles, templates, and container configs are POSIX-compliant (`/opt/...`, `/var/lib/...`, `/etc/...`). Windows-style paths (`C:\...`, backslashes, drive letters) appear **only** in tasks that bootstrap or configure a Windows host itself (e.g., installing Docker Desktop, setting up WSL2, creating local Windows users). Once a container is running, its filesystem is Linux — containers on Windows run under WSL2 and expect Linux paths.

Storage paths, volume mounts, config file destinations inside containers, and any path a containerized service reads must be POSIX. If a Windows-specific path is needed for host-level setup, scope it to that one task and do not let it leak into shared defaults or container-facing config.

#### 4. Ansible modules manage containers — NEVER `docker compose`

**This is non-negotiable. Violating it is a design error, not a style choice.**

All container lifecycle (create, start, stop, restart, remove), network management, and volume management MUST go through `community.docker` Ansible modules:
- `community.docker.docker_container` — manage containers
- `community.docker.docker_network` — manage networks
- `community.docker.docker_volume` — manage volumes
- `community.docker.docker_image` — build/pull images

**NEVER**:
- ❌ Copy `docker-compose*.yml` files to the target host and shell out to `docker compose up/down/build`
- ❌ Use `ansible.builtin.shell` or `ansible.builtin.command` to run `docker compose ...`
- ❌ Use `ansible.builtin.shell` to run `docker network connect/disconnect` — use `networks` parameter in `docker_container`
- ❌ Use `ansible.builtin.shell` to run `docker build` — build on the control machine, push to the local registry, then use `community.docker.docker_image` with `source: pull` in the role (see Invariant #2 above)
- ❌ Rely on `.env` files alongside compose files for variable interpolation
- ❌ Create compose files in `shared/active/03-container/services/` and expect them to be deployed to the server

**Why**:
1. **Idempotency**: `community.docker` modules report `changed`/`ok` status. `docker compose up` always reports changed, breaking idempotency.
2. **Variable-driven**: All config (ports, IPs, env vars, volumes, networks) comes from Ansible variables and vault secrets — no file interpolation, no `.env` files, no compose variable substitution.
3. **Single source of truth**: The Ansible role IS the container definition. There is no second definition in a compose file that can drift.
4. **No file copying**: Playbooks don't copy compose files to the target. The role defines the container inline, Ansible applies it directly.
5. **Network management**: Networks are created via `docker_network` with proper subnet/gateway config, not via `docker network create` shell commands. Static IPs are assigned via the `networks` parameter in `docker_container`, not via post-hoc `docker network connect` shell commands.

**Compose files in `shared/active/03-container/services/`**: These exist as **reference/documentation only** — they show the intended topology for human reading. They are NOT deployed to servers. They are NOT copied by playbooks. They are NOT used at runtime. If a compose file and an Ansible role disagree, the Ansible role is correct and the compose file is stale.

**If a playbook currently copies compose files and shells out to `docker compose`**: That playbook is broken by design. Refactor it to use `include_role` with the proper `community.docker` roles. The roles already exist in `shared/active/02-config/ansible/roles/` — use them.

#### 5. Services run in containers — NEVER as host-level systemd services

**This is non-negotiable. Violating it is a design error, not a style choice.**

Every service deployed by an Ansible role runs inside a Docker container managed via `community.docker.docker_container` — not as a host-level systemd unit, not as a bare binary on the host, not as a background process. This includes agents, collectors, proxies, monitors, and any other long-running process.

**NEVER**:
- ❌ Deploy a service as a systemd unit on the target host (writing `.service` files to `/etc/systemd/system/`)
- ❌ Fetch a binary on the control machine and copy it to the target for host-level execution
- ❌ Use `ansible.builtin.systemd` to start/enable a service that could run in a container
- ❌ Install a service via `apt`/`dnf`/`pip` on the target and run it as a host process

**The ONLY exceptions** are:
1. **Docker engine itself** — must run as a host service (it IS the container runtime)
2. **Tailscale/Netbird** — runs as a host-level daemon for network connectivity (needed before containers can start)
3. **SSH/sshd** — host-level service for Ansible access
4. **KVM/QEMU** — Virtualization
5. **A documented, client-specific reason** — called out with a `# HOST-SERVICE JUSTIFIED:` comment explaining why containerization is impossible

**Why**:
1. **Consistency**: Every service is defined the same way — a `community.docker.docker_container` task in an Ansible role. No mixed deployment patterns.
2. **Isolation**: Containers provide filesystem, network, and process isolation. Host-level services share the host's filesystem and process table.
3. **GPU passthrough works**: `--gpus all` (NVIDIA) or `--device /dev/dri` (AMD/Intel) gives containers full GPU access. There is no need to run GPU-dependent services on the host.
4. **Reproducibility**: The container image is the unit of deployment. The same image runs on any host with Docker. Host-level deployments depend on host state (installed packages, library versions, kernel modules).
5. **Lifecycle management**: `docker_container` handles start/stop/restart/recreate idempotently. systemd units require separate handlers, daemon-reloads, and are outside the container management pattern.
6. **No host pollution**: Containers don't install packages on the host, don't leave binaries in `/usr/local/bin`, don't create users, don't modify host config files. The host stays clean.

**If a role currently deploys a systemd service**: That role is broken by design. Refactor it to deploy a container instead. If an official Docker image exists (check Docker Hub, GitHub Container Registry), use `source: pull`. If a custom image is needed, build it on the control machine, push to the local registry, and use `source: pull` in the role (see Invariant #2).

#### 6. Traefik routing uses container names — NEVER hardcoded IPs

Traefik dynamic config files (`/opt/traefik/config/dynamic/*.yml`) MUST reference backend services by **container name** (`http://<container_name>:<port>`), NEVER by hardcoded container IP (`http://172.31.0.X:<port>`). Container IPs are ephemeral — they change on every container recreation, network reconnection, or host restart. A hardcoded IP produces a 502 Bad Gateway the next time the container is recreated, even though the container is healthy.

The Docker provider is disabled in Traefik v3.0 (API incompatibility), so container labels are ignored — routing is via the file provider only. Dynamic config files are the single source of truth for routers, and they are deployed from Ansible templates in `roles/proxy-traefik/templates/dynamic/`.

**✅ Correct** (survives container recreation — Docker DNS resolves the name on the shared network):
```yaml
services:
  omniroute:
    loadBalancer:
      servers:
        - url: "http://localnet-ai-omniroute:20128"
```

**❌ Wrong** (breaks on container recreation — the IP is stale):
```yaml
services:
  omniroute:
    loadBalancer:
      servers:
        - url: "http://172.31.0.7:20128"
```

**Rules**:
- Every Traefik dynamic config template MUST use `{{ <service>_container_name | default('<name>') }}` for the server URL, never an IP.
- The target container MUST be connected to the `traefik-network` Docker network so Traefik can resolve the name.
- New service routers are added as templates in `roles/proxy-traefik/templates/dynamic/<domain>.yml.j2` with a deploy task in `roles/proxy-traefik/tasks/main.yml`, gated by an `<service>_enabled` flag in `roles/proxy-traefik/defaults/main.yml` and enabled in the client's `host_vars`.
- The `redirect-to-https` middleware is defined once in `middlewares.yml.j2` — per-domain templates reference it, they do not redefine it.

**If a dynamic config file has a hardcoded IP**: It was created manually outside the role. Replace it with a proper template in `roles/proxy-traefik/templates/dynamic/` and a deploy task in the role. Do not hand-edit the file on the server.

#### 7. Bind mounts use userns-remap UID — NEVER root (0)

Docker userns-remap is enabled on all target hosts (`docker_engine_userns_remap: "default"` → dockremap UID 100000). This means container root maps to **UID 100000** on the host, not UID 0. When a container bind-mounts a host directory and needs to write to it, the directory and its files MUST be owned by UID 100000:100000 on the host — not root (0).

If a bind-mounted directory is owned by root (0), the container gets `EACCES: permission denied` when trying to write. This causes silent failures: containers start but can't write logs, config, or data. Healthchecks may pass (read-only) while the service is broken.

**Rules**:
- Use `infra_storage_userns_remap_uid` (default 100000) and `infra_storage_userns_remap_gid` (default 100000) from `infrastructure/storage.yml` for all bind mount directory ownership in Ansible tasks.
- The `ansible.builtin.file` and `ansible.builtin.template` tasks that create files in bind-mounted paths MUST set `owner` and `group` to the userns-remap UID/GID, not `root`.
- Docker volumes (managed by Docker) handle this automatically — only bind mounts need explicit ownership.
- If a container uses a Docker volume and you switch it to a bind mount, you MUST update the ownership.

**Symptom**: Container logs show `EACCES: permission denied, mkdir '/app/config/logs'` or `permission denied` writing to config files. The container appears "running" but the service returns 500 or silently fails.

#### 8. Ansible variable precedence — host_vars override inventory vars

In Ansible, **host_vars take precedence over inventory group_vars**. If a variable is set in both `host_vars/oci-cloud-server.yml` and `inventories/oci.yml` (under `vars:`), the host_vars value wins.

This caused a critical security issue: Authelia secrets were defined as vault references (`{{ vault_authelia_admin_password }}`) in the inventory, but hardcoded default values in host_vars silently overrode them. The vault was never consulted.

**Rules**:
- **Secrets**: NEVER set secret values in host_vars. Set them as vault references (`{{ vault_* }}`) in the inventory `vars:` section. Host_vars should only contain non-secret configuration (ports, domains, feature flags).
- **Vault-referenced variables**: If a variable is defined as `{{ vault_* }}` in the inventory, do NOT also define it in host_vars — even with the same value. The host_vars version will shadow the vault reference.
- **When to use host_vars vs inventory vars**:
  - `host_vars/<host>.yml`: Host-specific connection details, non-secret config (ports, domains, enabled flags, container names)
  - `inventories/<env>.yml` `vars:`: Group-level config including all vault secret references
  - `inventories/group_vars/*.vault.yml`: Encrypted vault values (the actual secrets)
- **If a secret needs to be different per host**: Use a host-specific vault variable (e.g., `vault_authelia_admin_password_host1`) and reference it in the inventory, not in host_vars.

#### 9. Cloudflare DNS uses CNAMEs to Tailscale FQDNs — NEVER A records to Tailscale IPs

All services accessible via `*.levonk.com` run on Tailscale-attached hosts. Tailscale IPs are ephemeral — they can change on node re-registration, tailnet reconfiguration, or provider migration. Cloudflare DNS records MUST use **CNAMEs** pointing to Tailscale FQDNs (e.g., `oci.tale-grouper.ts.net`), NEVER A records pointing to Tailscale IPs (e.g., `100.90.22.85`).

A CNAME decouples Cloudflare DNS from the ephemeral IP. If Tailscale reassigns the IP, only Tailscale's internal DNS updates — Cloudflare is untouched. With an A record, every Cloudflare record must be manually updated.

**Rules**:
- DNS records in `configure-cloudflare-dns.yml` and all `deploy-*.yml` playbooks MUST use `type: "CNAME"` with `content: "{{ infra_tailscale_fqdn_* }}"`.
- The Tailscale tailnet name and per-host FQDNs are defined in `levonk/active/02-config/ansible/infrastructure/domains.yml` (`infra_tailscale_tailnet`, `infra_tailscale_fqdn_cloud_server`, `infra_tailscale_fqdn_inference_host`).
- The `cloudflare-dns` role handles A→CNAME migration automatically: if a conflicting A record exists, it deletes it before creating the CNAME.
- Cloudflare must stay in DNS-only mode (grey cloud, not proxied) — if proxied, Cloudflare would try to resolve the CNAME target and fail (Tailscale FQDNs are not publicly resolvable).
- New Tailscale-attached hosts get a CNAME in `configure-cloudflare-dns.yml` pointing to their Tailscale FQDN.

### Per-Client Centralized Files

Every client directory (`<client>/active/02-config/ansible/`) MUST contain this set of centralized files. They are the single source of truth for that client — `shared/` only holds the schemas and neutral defaults, the client directory holds the actual values.

| File | Purpose |
|------|---------|
| `group_vars/infrahub-<client>-all.vault.yml` | Vault — all secrets (API keys, tokens, passwords). Encrypted with Ansible vault. |
| `infrastructure/domains.yml` | Hostnames, DNS records, domain names |
| `infrastructure/ports.yml` | Port allocations (host/container ports by service) |
| `infrastructure/networks.yml` | Network topology — subnets, gateways, network names, IP allocations |
| `infrastructure/storage.yml` | Storage paths, volumes, container mounts |

Rules:

- **All five files are required per client.** A new client is not onboarded until this set exists.
- **No client-specific values in `shared/`.** `shared/active/02-config/ansible/infrastructure/` holds schemas and neutral defaults only; actual values live in the client directory.
- **No infrastructure values in regular `group_vars`/`host_vars`.** IPs, ports, domains, storage paths go in `infrastructure/*.yml`, not in `group_vars/all.yml`. The vault file is the only `group_vars` file that holds client-specific values, and it holds secrets only.
- **Variable naming**: `infra_{CATEGORY}_{SERVICE}_{CONTEXT}_{ATTRIBUTE}` (e.g., `infra_port_worldmonitor_host`, `infra_domain_worldmonitor_web`, `infra_storage_worldmonitor_repo`).
- **Reference, don't duplicate.** Playbooks and roles reference these variables; they never hardcode the values and never re-declare them elsewhere.

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
