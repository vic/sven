# Step one: the whole old file as one aspect. Use it with modules/fleet.nix and modules/laptop.nix only.
{ yen, ... }:
{
  yen.aspects.legacy = {
    at = yen.host.laptop;
    nixos = ../before/configuration.nix;
  };
}
