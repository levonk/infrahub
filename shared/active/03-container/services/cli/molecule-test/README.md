# Molecule Test Environment

Compliant Docker image for Ansible Molecule role testing.

## Purpose

Provides a containerized environment for testing Ansible roles via Molecule, with:
- Ansible for role execution
- Docker Python library for container management
- pytest-testinfra for infrastructure testing
- Based on `localnet-base-debian` for security hardening and consistency

## Usage

### Build the image

```bash
cd ~/p/gh/levonk/infrahub
nx run localnet-molecule-test:docker:build
```

### Use in Molecule tests

Update molecule configuration files to use this image:

```yaml
# molecule/default/molecule.yml
driver:
  name: docker
platforms:
  - name: instance
    image: localnet-molecule-test:latest
```

## Security

- Non-root execution via `cuser` (UID/GID 1000)
- Based on hardened `localnet-base-debian` image
- Follows Docker Service Standards (ADR-20251218002)
- Minimal attack surface with only necessary packages

## Standards Compliance

- **Base Image**: `localnet-base-debian:latest` (from `services/base/base-debian`)
- **User**: `cuser` with UID/GID 1000 (project standard)
- **Security**: Inherits hardening from base image
- **Structure**: Follows canonical service layout
