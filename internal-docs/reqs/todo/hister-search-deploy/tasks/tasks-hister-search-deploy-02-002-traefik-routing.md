---
story_id: "02-002"
story_title: "Add Traefik routing to proxy_traefik_windows"
story_name: "traefik-routing"
prd_name: "hister-search-deploy"
prd_file: "internal-docs/feature/todo/hister-search-deploy/feat-202608222054-hister-search-deploy.md"
phase: 2
parallel_id: 2
branch: "feature/current/hister-search-deploy/story-02-002-traefik-routing"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["01-001", "02-001"]
parallel_safe: false
modules: ["traefik", "proxy"]
priority: "MUST"
risk_level: "low"
tags: ["traefik", "ansible", "routing"]
due: "2026-08-22"
create-date: "2026-08-22"
update-date: "2026-08-22"
---

## Summary

Add Traefik dynamic configuration for Hister to the `proxy_traefik_windows`
role. This includes the dynamic config template (HTTP/HTTPS routers with
Authelia middleware), render/copy tasks, and network connect task.

## Sub-Tasks

- [ ] Create `templates/dynamic/hister-nl.yml.j2` dynamic config template
- [ ] Add hister defaults to `proxy_traefik_windows/defaults/main.yml`
- [ ] Add render task to `proxy_traefik_windows/tasks/main.yml`
- [ ] Add copy task to `proxy_traefik_windows/tasks/main.yml`
- [ ] Add network connect task to `proxy_traefik_windows/tasks/main.yml`

## Relevant Files

- `shared/active/02-config/ansible/roles/proxy_traefik_windows/templates/dynamic/hister-nl.yml.j2` — new
- `shared/active/02-config/ansible/roles/proxy_traefik_windows/defaults/main.yml` — modify
- `shared/active/02-config/ansible/roles/proxy_traefik_windows/tasks/main.yml` — modify

## Acceptance Criteria

- Given the dynamic config template, When rendered, Then it produces HTTP router (redirect to HTTPS) and HTTPS router (with Authelia middleware and TLS certResolver)
- Given the Traefik role tasks, When executed, Then the hister-nl.yml dynamic config is rendered and copied into the config volume
- Given the Hister container is running, When Traefik processes the dynamic config, Then it routes hister.nl.levonk.com to the hister container on port 4433

## Implementation Notes

### Dynamic config template (hister-nl.yml.j2)
Follow the pattern from `start-nl.yml.j2`:
```yaml
# Traefik Dynamic Configuration - Hister (nl) — Windows
# Domain: {{ search_hister_domain }}
# Security: Authelia SSO

http:
  routers:
    hister-nl-http:
      rule: "Host(`{{ search_hister_domain }}`)"
      entryPoints:
        - web
      middlewares:
        - redirect-to-https
      service: hister-nl

    hister-nl-https:
      rule: "Host(`{{ search_hister_domain }}`)"
      entryPoints:
        - websecure
      middlewares:
        - authelia
      service: hister-nl
      tls:
        certResolver: letsencrypt

  services:
    hister-nl:
      loadBalancer:
        servers:
          - url: "http://{{ search_hister_container_name }}:{{ search_hister_container_port }}"
        passHostHeader: true
```

### Defaults to add (proxy_traefik_windows/defaults/main.yml)
```yaml
# Hister Integration
proxy_traefik_windows_hister_enabled: true
proxy_traefik_windows_hister_domain: "{{ search_hister_domain | default('hister.nl.levonk.com') }}"
proxy_traefik_windows_hister_container_name: "{{ search_hister_container_name | default('localnet-hister') }}"
proxy_traefik_windows_hister_container_port: "{{ search_hister_container_port | default('4433') }}"
```

### Tasks to add (proxy_traefik_windows/tasks/main.yml)
1. Render task (after existing render tasks, before network management):
```yaml
- name: Render Hister (nl) dynamic config locally
  ansible.builtin.template:
    src: dynamic/hister-nl.yml.j2
    dest: "{{ proxy_traefik_windows_temp_dir }}/dynamic/hister-nl.yml"
    mode: "0644"
  delegate_to: localhost
  run_once: true
  changed_when: false
  when: proxy_traefik_windows_hister_enabled | bool
  tags: ["deploy", "config"]
```

2. Copy task (after existing copy tasks):
```yaml
- name: Copy Hister (nl) dynamic config into volume
  ansible.builtin.command: >-
    docker cp {{ proxy_traefik_windows_temp_dir }}/dynamic/hister-nl.yml
    {{ proxy_traefik_windows_container_name }}-config-seed:/config/dynamic/hister-nl.yml
  environment:
    DOCKER_HOST: "{{ proxy_traefik_windows_docker_host }}"
  delegate_to: localhost
  changed_when: true
  when: proxy_traefik_windows_hister_enabled | bool
  tags: ["deploy", "config"]
```

3. Network connect task (in network management section):
```yaml
- name: Connect Hister container to traefik-windows network
  ansible.builtin.shell: >-
    docker network connect {{ proxy_traefik_windows_network_name }}
    {{ proxy_traefik_windows_hister_container_name }} 2>/dev/null || true
  environment:
    DOCKER_HOST: "{{ proxy_traefik_windows_docker_host }}"
  delegate_to: localhost
  changed_when: false
  when: proxy_traefik_windows_hister_enabled | bool
  tags: ["deploy", "network"]
```

## Definition of Done

- Dynamic config template follows existing nl service pattern
- Authelia middleware included on HTTPS router
- Render, copy, and network connect tasks added to proxy_traefik_windows
- All references use `search_hister_*` variables from the role defaults
