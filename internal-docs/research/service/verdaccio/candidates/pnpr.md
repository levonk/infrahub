# pnpr (pnpm registry server)

- **Repo**: Part of pnpm monorepo (https://github.com/pnpm/pnpm)
- **Status**: Experimental | **Language**: Rust
- **Image**: No official Docker images

## Why not for this use case

- **Experimental**: Not production-ready. APIs may change.
- **No official Docker images**: Must build from source for each architecture.
- **No multi-arch support**: ARM64 requires Rust compilation.
- **Breaking changes**: No Basic auth on requests (bearer tokens only).

## Verdict

Wait until stable with official multi-arch Docker images. For now, Verdaccio is production-ready.
