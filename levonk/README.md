# Private Infra Overlay

This directory contains personal/private infrastructure content that overlays the
public `shared/` tree in the parent repo.

## Directory Layout

Mirrors `shared/active/` so private inventory, host_vars, secrets, and local
deploy configs can live here without exposing them in the public repository.

## Usage

Ansible playbooks reference this overlay via:

```bash
ansible-playbook \
  -i levonk/active/02-config/ansible/inventories/production.yml \
  shared/active/02-config/ansible/playbooks/site.yml
```

## Rules

- Never commit secrets, real host IPs, or credentials.
- Use `ansible-vault` for sensitive variables.
- Keep this repo private.
