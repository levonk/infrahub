# Role Template: Container Deployment

Template structure for a new container deployment role in infrahub.

## Directory Structure

```
shared/active/02-config/ansible/roles/{functional_group}_{service}/
├── defaults/
│   └── main.yml          # Default values (no fallbacks in tasks)
├── tasks/
│   └── main.yml          # Main task flow
├── handlers/
│   └── main.yml          # Handlers (if any)
└── vars/
    └── main.yml          # Internal role variables (if any)
```

## defaults/main.yml

```yaml
---
# Service configuration defaults
{service}_container_name: "{functional_group}-{service}"
{service}_image_name: "{{ infra_registry }}/{category}/{service}:{{ {service}_image_tag | default('latest') }}"
{service}_restart_policy: "unless-stopped"

# Ports (referenced from infrastructure variables)
{service}_host_port: "{{ infra_{category}_{service}_host_port }}"
{service}_container_port: "{{ infra_{category}_{service}_container_port }}"

# Volumes (bind mounts use UID 100000 for userns-remap)
{service}_data_dir: "{{ infra_{category}_{service}_data_dir }}"

# Environment
{service}_env:
  PUID: "100000"
  PGID: "100000"
  TZ: "{{ infra_timezone | default('UTC') }}"
```

## tasks/main.yml

```yaml
---
- name: Gather ansible_facts
  ansible.builtin.setup:
    gather_subset: ["all"]

- name: Validate required variables are defined
  ansible.builtin.assert:
    that:
      - infra_{category}_{service}_host_port is defined
      - infra_{category}_{service}_container_port is defined
      - infra_{category}_{service}_data_dir is defined
    fail_msg: "ERROR: Required infrastructure variables not defined. Check shared/active/02-config/ansible/infrastructure/"
    success_msg: "All required variables are defined."

- name: Ensure data directory exists with correct ownership (userns-remap UID 100000)
  ansible.builtin.file:
    path: "{{ {service}_data_dir }}"
    state: directory
    owner: "100000"
    group: "100000"
    mode: "0755"

- name: Check if port is already in use
  ansible.builtin.wait_for:
    host: "{{ ansible_default_ipv4.address }}"
    port: "{{ {service}_host_port }}"
    state: stopped
    timeout: 5
  register: port_check
  failed_when: false
  ignore_errors: true

- name: Fail if port is already in use
  ansible.builtin.fail:
    msg: "ERROR: Port {{ {service}_host_port }} is already in use."
  when: port_check is succeeded

- name: Check if container exists
  community.docker.docker_container_info:
    name: "{{ {service}_container_name }}"
  register: existing_container
  ignore_errors: true

- name: Pull image
  community.docker.docker_image:
    name: "{{ {service}_image_name }}"
    source: pull

- name: Deploy container
  community.docker.docker_container:
    name: "{{ {service}_container_name }}"
    image: "{{ {service}_image_name }}"
    state: started
    restart_policy: "{{ {service}_restart_policy }}"
    ports:
      - "{{ {service}_host_port }}:{{ {service}_container_port }}"
    volumes:
      - "{{ {service}_data_dir }}:/data"
    env: "{{ {service}_env }}"
    cap_drop: ["ALL"]
    security_opts: ["no-new-privileges:true"]
    networks:
      - name: "{{ infra_{category}_network_name }}"
  when: existing_container.container is not defined or existing_container.container.Image != {service}_image_name
```

## Vault Handoff

When secrets are needed, the agent provides a `docker run` command with
placeholder values. The user adds actual secrets via:

```bash
ansible-vault edit shared/active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml
```

Add variables like:
```yaml
vault_{service}_api_token: "actual-token-here"
vault_{service}_password: "actual-password-here"
```

Reference in tasks with:
```yaml
{service}_env:
  API_TOKEN: "{{ vault_{service}_api_token | default('') }}"
```
