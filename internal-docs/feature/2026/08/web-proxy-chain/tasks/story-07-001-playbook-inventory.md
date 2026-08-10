---
story: "07-001"
title: "Playbook + inventory wiring + just recipes"
status: "[ ] Todo"
phase: 7
depends_on: ["05-001", "06-001"]
branch: "feature/current/web-proxy-chain/story-07-001-playbook-inventory"
---

# Story 07-001: Playbook + Inventory Wiring

## Goal

Create the `proxy-web-stack.yml` playbook, wire it to the correct inventories,
and add `just` recipes for deployment and validation.

## Files to create/modify

1. `shared/active/02-config/ansible/playbooks/deploy-proxy-web-stack.yml` — new playbook
2. `shared/active/02-config/ansible/playbooks/validate-proxy-web.yml` — validation playbook
3. `justfile` — add recipes
4. `devbox.json` — add scripts (if needed)

## Playbook structure

```yaml
---
# Deploy Web Proxy Chain
# Targets: windows_docker_hosts (dtop202311) + cloud_servers (oci-cloud-server)
- name: Deploy web proxy chain
  hosts: [windows_docker_hosts, cloud_servers]
  become: "{{ false if ansible_os_family == 'Windows' else true }}"
  roles:
    - role: proxy-web
      tags: [proxy-web]
```

## Just recipes to add

```makefile
# Deploy web proxy chain
ansible-deploy-proxy-web:
    devbox run -- ansible-playbook -i levonk/active/02-config/ansible/inventories/windows-docker.yml \
      -i levonk/active/02-config/ansible/inventories/oci.yml \
      shared/active/02-config/ansible/playbooks/deploy-proxy-web-stack.yml \
      --vault-password-file ~/.ansible/vault_password

# Validate web proxy chain
ansible-validate-proxy-web:
    devbox run -- ansible-playbook -i levonk/active/02-config/ansible/inventories/windows-docker.yml \
      -i levonk/active/02-config/ansible/inventories/oci.yml \
      shared/active/02-config/ansible/playbooks/validate-proxy-web.yml \
      --vault-password-file ~/.ansible/vault_password
```

## Acceptance criteria

- [ ] deploy-proxy-web-stack.yml playbook created
- [ ] validate-proxy-web.yml playbook created
- [ ] Just recipes added
- [ ] `just ansible-syntax` passes
- [ ] `just ansible-deploy-proxy-web --check` runs in check mode without errors
