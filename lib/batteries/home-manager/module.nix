#: lib.batteries.home-manager.module :: module -> module -- home-manager as a NixOS or nix-darwin module, with the machine pkgs
# home-manager as a NixOS or nix-darwin module, with the machine's pkgs: put it where a machine has users.
#   yen.aspects.home-manager = { at = has yen.kinds.user; nixos = home-manager.module inputs.home-manager.nixosModules.home-manager; };
module: {
  imports = [ module ];
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
}
