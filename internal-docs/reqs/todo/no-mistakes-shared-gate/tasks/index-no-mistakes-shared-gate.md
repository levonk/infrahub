# Task Index: no-mistakes Shared Git Gate Service

| Story ID | Title | Phase | Status | Parallel-safe | Dependencies | Dependants | Branch |
|---|---|---:|---|---|---|---|---|
| 01-001 | Shared infrastructure schemas | 01 | [x] Done | true | — | 02-001, 03-001 | feature/current/no-mistakes-shared-gate/story-01-001-shared-infra-schemas |
| 01-002 | Client infrastructure values + DNS | 01 | [x] Done | true | 01-001 | 03-001, 05-001 | feature/current/no-mistakes-shared-gate/story-01-002-client-infra-values |
| 02-001 | Service catalog entry + regeneration | 02 | [x] Done | true | 01-001, 01-002 | — | feature/current/no-mistakes-shared-gate/story-02-001-service-catalog |
| 03-001 | Container image Dockerfile + build pipeline | 03 | [x] Done | true | 01-001, 01-002 | 05-001 | feature/current/no-mistakes-shared-gate/story-03-001-container-image |
| 04-001 | Vault secrets (user handoff) | 04 | [!] Blocked | true | — | 05-001 | feature/current/no-mistakes-shared-gate/story-04-001-vault-secrets |
| 05-001 | Ansible role devops-no-mistakes | 05 | [x] Done | false | 01-002, 03-001, 04-001 | 06-001 | feature/current/no-mistakes-shared-gate/story-05-001-ansible-role |
| 06-001 | Deployment playbook | 06 | [x] Done | false | 05-001 | — | feature/current/no-mistakes-shared-gate/story-06-001-playbook |

## Notes

- **Phase 1** (stories 01-001, 01-002): Infrastructure schemas and client values. Parallel-safe — different files.
- **Phase 2** (story 02-001): Service catalog. Depends on infra vars existing.
- **Phase 3** (story 03-001): Container image. Depends on infra vars for port/domain references in Dockerfile.
- **Phase 4** (story 04-001): Vault secrets. Independent of code — can run in parallel with phases 1-3. Requires user handoff (agent cannot edit vault directly).
- **Phase 5** (story 05-001): Ansible role. Depends on infra vars, container image, and vault secrets. Not parallel-safe — single large story.
- **Phase 6** (story 06-001): Playbook. Depends on role existing.
