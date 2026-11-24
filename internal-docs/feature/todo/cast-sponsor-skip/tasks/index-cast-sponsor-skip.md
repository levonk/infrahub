# Task Index: CastSponsorSkip on minime01

**PRD**: `../feat-20261112-cast-sponsor-skip.md`
**Research**: `internal-docs/research/service/cast-sponsor-skip/`
**Implementation guide**: `.agents/workflows/infrahub-add-new-service.md`

## Stories

| Story ID | Title | Phase | Status | Parallel-safe | Dependencies | Dependants | Branch |
|---|---|---:|---|---|---|---|---|
| 01-001 | Research CastSponsorSkip + alternatives | 01 | [x] Done | true | — | all | `levonk/20261107-CastSponsorSkip` |
| 02-001 | `container-podman` role + `media-cast-sponsor-skip` role + `deploy-cast-sponsor-skip.yml` | 02 | [x] Done | false | 01-001 | 03-001, 04-001 | PR #34 (`1085eea1`) |
| 02-002 | minime01 onboarding — inventory, group_vars, machines.yml | 02 | [x] Done | true | 01-001 | 02-001 | levonk `7ab3b1b` et al. |
| 03-001 | services.yml catalog entry + regenerate both SERVICES.md | 03 | [x] Done | true | 02-001 | — | `levonk/20261107-CastSponsorSkip` |
| 04-001 | levonk justfile deploy + check + syntax recipes | 04 | [x] Done | true | 02-001 | — | `levonk/20261107-CastSponsorSkip` (levonk submodule) |
| 05-001 | Vault handoff — `vault_castsponsorskip_youtube_api_key` (optional) | 05 | [!] Blocked | true | — | 06-001 | user action |
| 06-001 | Ansible adopt/deploy run + verify discovery | 06 | [!] Blocked | false | 04-001, 05-001* | — | — |

\* 05-001 is optional — the service runs without the API key; only
Chromecast-with-Google-TV devices need it.

## Notes

- **Podman, not Docker**: minime01 has no Docker Engine — `container-podman`
  installs podman + enables `podman.socket`; a tmpfiles.d rule persists a
  `/run/docker.sock` → `/run/podman/podman.sock` symlink so
  `community.docker` modules work unmodified.
- **Host networking is mandatory** — mDNS multicast cannot cross NAT.
  Playbook must always run with `--limit minime01`.
- **Discovery gap**: as of 2026-11-12 the container is healthy but has
  discovered zero cast devices — the Chromecasts are not on
  `192.168.12.0/24`. See PRD "Known Issues".
- **Manual→Ansible adoption**: the running container was created by hand;
  the role's spec matches it (env, restart=always, host net, pidof
  healthcheck) so the first playbook run should be a no-op or single
  recreate.

## Status Legend

- `[ ]` Todo
- `[~]` In-Progress
- `[x]` Done
- `[!]` Blocked
