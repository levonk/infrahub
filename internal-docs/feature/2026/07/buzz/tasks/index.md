# Buzz Deployment Tasks

1. [x] Add Buzz port schema to `shared/active/02-config/ansible/infrastructure/ports.yml`
2. [x] Add Buzz port overrides to `levonk/active/02-config/ansible/infrastructure/ports.yml`
3. [x] Add Buzz network schema to `shared/active/02-config/ansible/infrastructure/networks.yml`
4. [x] Add Buzz domain/hostname to `shared/active/02-config/ansible/infrastructure/domains.yml`
5. [x] Add Buzz storage paths to `shared/active/02-config/ansible/infrastructure/storage.yml`
6. [x] Add `buzz.levonk.com` DNS record to `configure-cloudflare-dns.yml`
7. [x] Create `ai-buzz` Ansible role (defaults, tasks, handlers, meta)
8. [x] Create `deploy-buzz.yml` playbook
9. [x] Add Traefik dynamic config template `buzz-levonk-com.yml.j2`
10. [x] Add `ai_buzz_enabled` toggle and deploy task to `proxy-traefik`
11. [x] Add vault secrets for Buzz
12. [x] Deploy Buzz to OCI and verify health
13. [x] Deploy Traefik to load Buzz route
14. [x] Update `PIPELINE-AI.md` with Buzz as Paperclip peer
