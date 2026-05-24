# Troubleshooting
## Enviornment
It could be that the tools are installed but your enviornment is misconfigured.

- `bash --version`
- `nix --version` (to install see docs/reference/nix-install-x86-macos-sequoia.md)
- `devbox --version` (`nix profile add devbox`)
- `zsh --version` (`devbox add zsh`)
- `direnv info` (`devbox add direnv`)
- `git --version` (`devbox add git`)
- `docker --version` (`devbox add docker`)
- `just --version` (`devbox add just`)