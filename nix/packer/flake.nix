{
  description = "packer wrapper: re-exports nixpkgs packer with allowUnfree until NixOS/nixpkgs#576090 lands (fixes aarch64-darwin SIGSEGV via go-m1cpu bump). Revert to the plain `packer` package after merge.";

  inputs.nixpkgs.url = "github:levonk/nixpkgs/b3bfd1ceea250e426a6a6feda1cbbe0b45c385e4";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (system: {
        packer = (import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        }).packer;
      });
    };
}
