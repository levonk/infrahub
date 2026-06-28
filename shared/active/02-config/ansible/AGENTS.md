# Agent Documentation: Ansible

## Root Cause First - No Workarounds

**Root causing is essential. Do not work around long-term problems unless explicit permission is granted.**

- When a deployment fails, investigate the actual cause before retrying or trying alternatives.
- Failing early and surfacing the issue is preferable to working around it and raising the problem later.
- If a credential is expired, say so and tell the user where to update it - do not attempt manual authentication loops, state copying, or other band-aids.
- If a container keeps restarting, find out why (check restart count, logs, exit codes) before redeploying.
- Do not chain workaround on top of workaround. Each failed attempt should inform the next, not paper over the previous failure.
- When you encounter an existing resource that conflicts with a new one (e.g., a node already exists in Tailscale), stop and surface the conflict to the user. Do not proceed with a renamed variant without permission.

## Quick Reference

- **Project Type**: Ansible infrastructure and roles for cloud server deployment
- **Build System**: Devbox + Just
- **Test Framework**: Molecule for role testing (currently blocked due to Python docker module dependency)
- **Package Manager**: pnpm for Nix, but Ansible packages via devbox

## Devbox & Just Commands

**ALWAYS use `just` commands instead of `devbox run` for Ansible operations.**

### Molecule Testing (BLOCKED)

```bash
# Test specific role via Molecule
just molecule-test host-os-bootstrap
just molecule-test nix-installation
just molecule-test docker-engine

# Run all Molecule tests
just ansible-test-internal

# Manual container cleanup
just ansible-test-env-stop
```

**BLOCKER**: Molecule tests are currently blocked because:
- molecule-docker package doesn't exist in nixpkgs
- molecule requires Python docker module which isn't available
- molecule runs Ansible with restricted PATH (only Python package dirs), can't access system PATH where podman/docker binaries live
- Tried: podman driver, delegated driver, custom nix package with withPackages, python313Packages.podman (installed but molecule still can't find podman binary in Ansible PATH)
- Directory renamed from `molecule` to `.molecule` (molecule expects the directory to be named `.molecule`)

### Ansible Commands

```bash
# Lint all roles & playbooks
just ansible-lint

# Check playbook syntax
just ansible-syntax

# Run Molecule tests (Docker containers)
just ansible-test

# Deploy playbooks to OCI
just ansible-deploy-bootstrap
just ansible-deploy-vpn
just ansible-deploy-infra
just ansible-deploy-vms
just ansible-deploy-site

# Validate deployments
just ansible-validate-bootstrap
just ansible-validate-vpn
just ansible-validate-infra
just ansible-validate-vms
```

### Docker Test Environment

```bash
# Build test environment
just ansible-test-env-build

# Stop test container
just ansible-test-env-stop
```

## Repository Structure

```
shared/active/02-config/ansible/
├── roles/              # Ansible roles
│   ├── host-os-bootstrap/
│   ├── nix-installation/
│   └── docker-engine/
├── playbooks/          # Playbook files
├── group_vars/          # Group variables
├── inventories/        # Inventory files
└── collections/        # Ansible Galaxy collections
```

## Molecule Configuration

Molecule scenarios are in `.molecule/default/` within each role directory:

- `molecule.yml` - Driver and platform configuration
- `converge.yml` - Ansible playbook to apply the role
- `verify.yml` - Ansible playbook to verify role outcomes

## Testing Status

- **04-001**: ansible-lint configuration & role linting - DONE
- **04-002**: Molecule tests for critical roles - BLOCKED
- **04-003**: Playbook syntax check & dry-run - TODO

## Dependencies

- Depends on: devbox environment
- Requires: molecule, ansible, docker/podman
- Docker images: `debian:bookworm-slim` (matches OCI target)
