{ pkgs, ... }: {
  nix.settings = {
    # For Remote Dev
    keep-outputs = true;
    keep-derivations = true;

    # Experimental Features
    experimental-features = [ "nix-command" "flakes" ];

    # Flake registry settings
    flake-registry = "https://github.com/NixOS/flake-registry/raw/master/flake-registry.json";
    
    # Accept flake registry
    accept-flake-config = true;

    auto-optimise-store = true;
  };
}
