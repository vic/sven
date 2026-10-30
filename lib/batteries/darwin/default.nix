# nix-darwin.
{
  system = import ./system.nix;
  primary-user = import ./primary-user.nix;
  homebrew = import ./homebrew.nix;
}
