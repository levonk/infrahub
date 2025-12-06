{ pkgs, ... }: {
  nix.settings = {
    # For Remote Dev
    keep-outputs = true;
    keep-derivations = true;

    # Experimental Features
    experimental-features = [ "nix-command" "flakes" ];

    auto-optimise-store = true;
  };
}
