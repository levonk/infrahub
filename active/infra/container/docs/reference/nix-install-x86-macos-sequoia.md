
# Nix OS Install

Check if it's already working via `nix --version`

If it's not, there is a special exception for MacOS x86 Sequoia Install https://github.com/DeterminateSystems/nix-installer/issues/1707
- Support stopped at v3.12.2 is the last version to support Intel Macs
- `curl -fsSL https://install.determinate.systems/nix/tag/v3.12.2 | sh -s -- install`

Normal Nix Install `curl -fsSL https://install.determinate.systems/nix | sh -s -- install`