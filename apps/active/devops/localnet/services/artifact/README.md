# Artifact Repository Services

This service domain groups the on-premise artifact repositories that ship with the Homelab In-a-Box stack. Each package inside this directory maps to a deployed container that previously lived in the monolithic `docker-compose.yml`.

## Packages

- **nexus** — [Sonatype Nexus Repository Manager](https://www.sonatype.com/products/nexus-repository) for Docker, Maven, npm, and more.
- **verdaccio** — [Verdaccio](https://verdaccio.org/) as a local npm-compatible proxy and private registry.

Each package directory provides a consistent scaffold:

```
services/artifact/<package>/
  docker/          # Custom Dockerfiles or build context additions
  healthcheck/     # Supplemental health-check scripts or probes
  internal-docs/   # Design notes, runbooks, SOPs
  assets/          # Static assets bundled with the container
  mounts/          # Files mounted into the container at runtime
```

The directories currently contain `.gitkeep` placeholders so they remain tracked even when empty. Populate them with real artifacts as the services evolve.

## Compose file

`docker-compose.artifact.yml` defines the containers and is included from the root compose via the `include` directive. Runtime configuration continues to live under `../../configs/artifacts/` to avoid churn in existing automation.

## Getting started

```
pnpm --filter localnet docker compose up nexus verdaccio
```

The command above assumes the monorepo tooling wraps Docker Compose. Substitute the project-specific helper if a different entrypoint is used.
