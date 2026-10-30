# cachix binary caches: trust them in NixOS, nix-darwin, home-manager and flake.nix; push from CI.
{
  caches = import ./caches.nix;
  flake-config = import ./flake-config.nix;
  action = import ./action.nix;
}
