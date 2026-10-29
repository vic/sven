# What mkHost gave every host, and what easy-hosts gives per arch or per class: aspects at the host kind.
{ yen, ... }:
{
  yen.aspects.base = {
    at = yen.kinds.host;
    nixos =
      { host, ... }:
      {
        networking.hostName = host.name; # no specialArgs.hostname: the host is an arg
        nixpkgs.hostPlatform = host.system;
        nix.settings.experimental-features = [
          "nix-command"
          "flakes"
        ];
        system.stateVersion = "25.05";
      };
  };
  # per arch: `at` reads a field
  yen.aspects.arm = {
    at = s: (s.system or null) == "aarch64-linux";
    nixos.boot.loader.generic-extlinux-compatible.enable = true;
  };
  yen.aspects.laptop = {
    at = s: s.laptop or false;
    nixos.services.upower.enable = true;
  };
}
