---
name: ansible
description: Best practices for Ansible automation in infrahub - container-based deployments, vault integration, deprecation-free code, and proper variable management. Use when creating or modifying Ansible playbooks, roles, or configurations in the infrahub project.
---

# Ansible Best Practices for Infrahub

## Core Principles

### 1. Container-First Deployment
- **Never use docker-compose** in Ansible playbooks
- Use `community.docker.docker_container` directly for container management
- Pull images with `community.docker.docker_image` when needed
- Prefer building images with `community.docker.docker_image` source: build for custom containers

### 2. Avoid Deprecation Warnings
- **Always use `ansible_facts['key']` instead of `ansible_key`**
- Common replacements:
  - `ansible_os_family` → `ansible_facts['os_family']`
  - `ansible_architecture` → `ansible_facts['os_family']`
  - `ansible_distribution` → `ansible_facts['distribution']`
- Add explicit `ansible.builtin.setup` task at role start if facts are needed early
- Example:
  ```yaml
  - name: Gather ansible_facts
    ansible.builtin.setup:
      gather_subset: ["all"]
  ```

### 3. Vault Integration
- **Naming convention**: `group_name.vault.yml` (e.g., `infrahub-levonk-all.vault.yml`)
- **Location**: `group_vars/` directory in the same directory as inventory
- **Never name vault files** as `vault-group_name.yml` - Ansible won't recognize them
- Access vault variables with `{{ vault_variable_name | default('') }}`
- Always provide default values to prevent empty string errors

### 4. Variable Management
- **All ports must be variables** - never hardcode ports in tasks
- Define ports in `group_vars/{group_name}.yml` with consistent naming:
  - `{category}_{service}_{sub}_{host|container}_{port}`
  - Example: `cloud_server_nordvpn_wireguard_host_port: 51820`
- **Defaults belong in vars files, not tasks** - define defaults in `defaults/main.yml` without fallback
- Validate required variables at playbook start with clear error messages:
  ```yaml
  - name: Validate required variables are defined
    ansible.builtin.assert:
      that:
        - variable_name is defined
        - variable_name | length > 0
      fail_msg: "ERROR: variable_name is not defined or empty. Check group_vars/{group_name}.yml"
      success_msg: "All required variables are defined."
  ```
- Never use `{{ variable | default('') }}` in tasks - validate upfront instead

### 5. Port Collision Detection
- **Check for port conflicts before deploying containers**
- Use `ansible.builtin.wait_for` to detect if port is already in use:
  ```yaml
  - name: Check if port is already in use
    ansible.builtin.wait_for:
      host: "{{ ansible_default_ipv4.address }}"
      port: "{{ host_port }}"
      state: stopped
      timeout: 5
    register: port_check
    failed_when: false
    ignore_errors: true

  - name: Fail if port is already in use
    ansible.builtin.fail:
      msg: "ERROR: Port {{ host_port }} is already in use. Check running containers with 'docker ps' and either stop the conflicting service or choose a different port."
    when: port_check is succeeded
  ```
- For existing containers, check if they're using the target port:
  ```yaml
  - name: Get all running containers
    community.docker.docker_container_info:
      name: "{{ item }}"
    loop: "{{ all_containers }}"
    register: container_info

  - name: Check for port conflicts
    ansible.builtin.set_fact:
      port_conflicts: []
    loop: "{{ container_info.results }}"
    when: item.container.HostConfig.PortBindings is defined

  - name: Fail on port conflicts
    ansible.builtin.fail:
      msg: "ERROR: Port {{ item }} is already in use by container {{ item.container.Name }}"
    when: item in port_conflicts
  ```
- Smart port selection: if collision detected, suggest alternative ports or auto-increment

### 6. Secret Management (CRITICAL)
- **NEVER commit plaintext keys, passwords, or secrets to git**
- All secrets must be stored in secure systems:
  - **Ansible Vault** - Use for Ansible-specific secrets (tokens, API keys, passwords)
  - **SOPS** - Use for encrypted files that need to be version-controlled
  - **Environment variables** - Use for runtime secrets (never commit .env files)
- **Ansible Vault pattern**:
  ```yaml
  # In group_vars/cloud_servers.yml
  cloud_server_token: "{{ vault_api_token }}"

  # In levonk/active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml (encrypted)
  vault_api_token: "your-actual-token-here"
  ```
- **SOPS pattern**:
  ```yaml
  # Use SOPS for files that need version control with encryption
  # Encrypt with: sops --encrypt --kms <key-id> file.yml
  # Decrypt with: sops --decrypt file.yml
  ```
- **Validation**: Add checks to ensure no plaintext secrets in committed files:
  ```yaml
  - name: Check for plaintext secrets in files
    ansible.builtin.command:
      cmd: grep -r "password\|secret\|token\|api_key" --include="*.yml" --include="*.yaml" {{ playbook_dir }}/
    register: secret_check
    failed_when: false
    changed_when: false

  - name: Fail if plaintext secrets found
    ansible.builtin.fail:
      msg: "ERROR: Plaintext secrets found in files. Use Ansible Vault or SOPS for secret management."
    when: secret_check.rc == 0
  ```
- **Never commit**:
  - `.env` files
  - Files with `password`, `secret`, `token`, `api_key` in plaintext
  - Unencrypted vault files
  - Private keys or certificates

### 5. Docker Container Best Practices
- **String conversion for env variables**: Always use `| string` filter for numeric env vars
  ```yaml
  env:
    HTTPPROXY_PORT: "{{ vpn_nordvpn_http_container_port | string }}"
  ```
- Use proper capabilities: `NET_ADMIN`, `NET_RAW` for VPN containers
- Expose TUN device: `devices: - /dev/net/tun`
- Use `cap_drop: - ALL` for security hardening
- Set `security_opts: - no-new-privileges:true` for additional security

### 7. Container Restart Logic
- **Check if container needs upgrade before redeploying** - don't blindly remove/recreate
- Compare current image with desired image
- Compare current environment variables with desired settings
- Compare current port bindings with desired ports
- Only redeploy if there are actual changes
- Report "already running with current version and settings" if no changes needed
- Pattern:
  ```yaml
  - name: Check if container exists
    community.docker.docker_container_info:
      name: "{{ container_name }}"
    register: existing_container
    ignore_errors: true

  - name: Check if container needs upgrade
    ansible.builtin.set_fact:
      needs_redeploy: false
      upgrade_reason: []
    when: existing_container.container is defined

  - name: Compare image version
    ansible.builtin.set_fact:
      needs_redeploy: true
      upgrade_reason: "{{ upgrade_reason + ['image upgrade'] }}"
    when:
      - existing_container.container is defined
      - existing_container.container.Image != image_name

  - name: Compare environment variables
    ansible.builtin.set_fact:
      needs_redeploy: true
      upgrade_reason: "{{ upgrade_reason + ['environment variables changed'] }}"
    when:
      - existing_container.container is defined
      - existing_container.container.Config.Env != desired_env_vars

  - name: Compare port bindings
    ansible.builtin.set_fact:
      needs_redeploy: true
      upgrade_reason: "{{ upgrade_reason + ['port bindings changed'] }}"
    when:
      - existing_container.container is defined
      - existing_container.container.HostConfig.PortBindings != desired_ports

  - name: Report container is up to date
    ansible.builtin.debug:
      msg: "Container {{ container_name }} is already running with current version and settings. No redeploy needed."
    when:
      - existing_container.container is defined
      - not needs_redeploy

  - name: Redeploy container if changes detected
    ansible.builtin.debug:
      msg: "Redeploying container {{ container_name }}. Reasons: {{ upgrade_reason | join(', ') }}"
    when:
      - existing_container.container is defined
      - needs_redeploy

  - name: Stop existing container for redeploy
    community.docker.docker_container:
      name: "{{ container_name }}"
      state: stopped
    when:
      - existing_container.container is defined
      - needs_redeploy

  - name: Remove existing container for redeploy
    community.docker.docker_container:
      name: "{{ container_name }}"
      state: absent
      force_kill: true
    when:
      - existing_container.container is defined
      - needs_redeploy

  - name: Deploy new container
    community.docker.docker_container:
      name: "{{ container_name }}"
      image: "{{ image_name }}"
      state: started
    when:
      - existing_container.container is not defined or needs_redeploy
  ```

### 8. Health Checks and Validation
- Add health checks with proper timing:
  ```yaml
  - name: Wait for container to be ready
    ansible.builtin.pause:
      seconds: 30
  ```
- Conditionally run health checks only when container is running:
  ```yaml
  - name: Verify service health
    ansible.builtin.command:
      cmd: docker exec {{ container_name }} {{ health_check_command }}
    when: container_info.container.State.Status == "running"
  ```
- Add descriptive debug messages for troubleshooting

### 9. Role Structure
- Follow standard Ansible role structure:
  ```
  roles/
  └── role-name/
      ├── defaults/main.yml    # Default variables
      ├── handlers/main.yml    # Handlers
      ├── meta/main.yml        # Metadata
      ├── tasks/main.yml       # Tasks
      ├── templates/           # Jinja2 templates
      └── files/              # Static files
  ```
- Use `become: true` for tasks requiring root privileges
- Use `ignore_errors: true` for non-critical validation tasks

### 10. Playbook Organization
- Use `pre_tasks` for validation and setup
- Use `post_tasks` for verification and cleanup
- Tag tasks for selective execution:
  ```yaml
  tags: ["validate", "ssh", "bootstrap"]
  ```
- Use `--tags` or `--skip-tags` for targeted runs

### 11. Error Handling
- Use `failed_when` for custom failure conditions
- Use `changed_when` to control idempotency
- Add descriptive `fail_msg` and `success_msg` in assertions
- Use `ignore_errors: true` for non-critical operations

## Common Patterns

### Container Deployment Pattern
```yaml
- name: Validate required variables
  ansible.builtin.assert:
    that:
      - image_name is defined
      - container_name is defined
      - host_port is defined
      - container_port is defined
    fail_msg: "ERROR: Required variables not defined. Check group_vars/{group_name}.yml"
    success_msg: "All required variables are defined."

- name: Check if port is already in use
  ansible.builtin.wait_for:
    host: "{{ ansible_default_ipv4.address }}"
    port: "{{ host_port }}"
    state: stopped
    timeout: 5
  register: port_check
  failed_when: false
  ignore_errors: true

- name: Fail if port is already in use
  ansible.builtin.fail:
    msg: "ERROR: Port {{ host_port }} is already in use. Check running containers with 'docker ps' and either stop the conflicting service or choose a different port."
  when: port_check is succeeded

- name: Pull container image
  community.docker.docker_image:
    name: "{{ image_name }}"
    source: pull
    state: present

- name: Check if container exists
  community.docker.docker_container_info:
    name: "{{ container_name }}"
  register: existing_container
  ignore_errors: true

- name: Check if container needs upgrade
  ansible.builtin.set_fact:
    needs_redeploy: false
    upgrade_reason: []
  when: existing_container.container is defined

- name: Compare image version
  ansible.builtin.set_fact:
    needs_redeploy: true
    upgrade_reason: "{{ upgrade_reason + ['image upgrade'] }}"
  when:
    - existing_container.container is defined
    - existing_container.container.Image != image_name

- name: Compare environment variables
  ansible.builtin.set_fact:
    needs_redeploy: true
    upgrade_reason: "{{ upgrade_reason + ['environment variables changed'] }}"
  when:
    - existing_container.container is defined
    - existing_container.container.Config.Env != desired_env_vars

- name: Compare port bindings
  ansible.builtin.set_fact:
    needs_redeploy: true
    upgrade_reason: "{{ upgrade_reason + ['port bindings changed'] }}"
  when:
    - existing_container.container is defined
    - existing_container.container.HostConfig.PortBindings != desired_ports

- name: Report container is up to date
  ansible.builtin.debug:
    msg: "Container {{ container_name }} is already running with current version and settings. No redeploy needed."
  when:
    - existing_container.container is defined
    - not needs_redeploy

- name: Redeploy container if changes detected
  ansible.builtin.debug:
    msg: "Redeploying container {{ container_name }}. Reasons: {{ upgrade_reason | join(', ') }}"
  when:
    - existing_container.container is defined
    - needs_redeploy

- name: Stop existing container for redeploy
  community.docker.docker_container:
    name: "{{ container_name }}"
    state: stopped
  when:
    - existing_container.container is defined
    - needs_redeploy

- name: Remove existing container for redeploy
  community.docker.docker_container:
    name: "{{ container_name }}"
    state: absent
    force_kill: true
  when:
    - existing_container.container is defined
    - needs_redeploy

- name: Deploy new container
  community.docker.docker_container:
    name: "{{ container_name }}"
    image: "{{ image_name }}"
    state: started
    restart_policy: unless-stopped
    capabilities:
      - NET_ADMIN
      - NET_RAW
    cap_drop:
      - ALL
    env:
      VAR_NAME: "{{ variable_value | string }}"
    ports:
      - "{{ host_port }}:{{ container_port }}"
    volumes:
      - "{{ volume_name }}:/path"
  when:
    - existing_container.container is not defined or needs_redeploy
```

### OS Family Detection Pattern
```yaml
- name: Gather ansible_facts
  ansible.builtin.setup:
    gather_subset: ["all"]

- name: Install packages (Debian)
  ansible.builtin.apt:
    name: "{{ packages }}"
    state: present
  when: ansible_facts['os_family'] == "Debian"

- name: Install packages (RedHat)
  ansible.builtin.dnf:
    name: "{{ packages }}"
    state: present
  when: ansible_facts['os_family'] == "RedHat"
```

### Vault Variable Pattern
```yaml
# In group_vars/cloud_servers.yml
cloud_server_token: "{{ vault_api_token }}"

# In levonk/active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml
vault_api_token: "your-actual-token-here"

# In tasks - validate vault variable is defined
- name: Validate vault variable is defined
  ansible.builtin.assert:
    that:
      - vault_api_token is defined
      - vault_api_token | length > 0
    fail_msg: "ERROR: vault_api_token is not defined or empty. Check levonk/active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml"
    success_msg: "Vault variable validated."

- name: Use vault variable
  ansible.builtin.debug:
    msg: "Token: {{ cloud_server_token }}"
```

## Anti-Patterns to Avoid

### ❌ Don't Use Docker Compose
```yaml
# WRONG
- name: Run docker-compose
  community.docker.docker_compose:
    project_src: /path/to/docker-compose.yml

# RIGHT
- name: Deploy container directly
  community.docker.docker_container:
    name: "{{ container_name }}"
    image: "{{ image_name }}"
    state: started
```

### ❌ Don't Hardcode Ports
```yaml
# WRONG
- name: Deploy container
  community.docker.docker_container:
    ports:
      - "51820:51820"

# RIGHT
- name: Deploy container
  community.docker.docker_container:
    ports:
      - "{{ cloud_server_service_host_port }}:{{ cloud_server_service_container_port }}"
```

### ❌ Don't Use Deprecated Fact Syntax
```yaml
# WRONG
when: ansible_os_family == "Debian"

# RIGHT
when: ansible_facts['os_family'] == "Debian"
```

### ❌ Don't Forget String Conversion
```yaml
# WRONG
env:
  PORT: "{{ port_number }}"

# RIGHT
env:
  PORT: "{{ port_number | string }}"
```

### ❌ Don't Use Wrong Vault Naming
```yaml
# WRONG - Ansible won't recognize this
vault-infrahub-levonk-all.yml

# RIGHT
infrahub-levonk-all.vault.yml
```

### ❌ Don't Commit Plaintext Secrets
```yaml
# WRONG - Plaintext secret in committed file
api_token: "my-secret-token-here"
password: "my-password-here"

# RIGHT - Use Ansible Vault
api_token: "{{ vault_api_token }}"
# In levonk/active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml (encrypted)
vault_api_token: "my-secret-token-here"

# RIGHT - Use SOPS for encrypted files
# Encrypt with: sops --encrypt --kms <key-id> secrets.yml
# Decrypt with: sops --decrypt secrets.yml
```

## Validation Checklist

Before committing Ansible changes:
- [ ] No docker-compose usage
- [ ] All `ansible_` prefixes replaced with `ansible_facts['key']`
- [ ] All ports are variables (no hardcoded ports)
- [ ] Vault files named correctly (group_name.vault.yml)
- [ ] Numeric env variables use `| string` filter
- [ ] Container restart logic is idempotent
- [ ] Health checks are conditional on container state
- [ ] Proper capabilities and security options set
- [ ] **All required variables validated at playbook start with clear error messages**
- [ ] **No `default()` filters in tasks - defaults belong in vars files**
- [ ] **Port collision detection before container deployment**
- [ ] **Vault variables validated for existence and non-empty**
- [ ] **No plaintext secrets, passwords, or keys in committed files**
- [ ] **Secrets stored in Ansible Vault, SOPS, or environment variables only**
- [ ] **Validation checks for plaintext secrets in YAML files**
- [ ] Tasks are properly tagged for selective execution
