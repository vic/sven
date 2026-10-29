# machine is data only (nothing spawns it): host, guest and mac copy its fields.
{ yen, lib, ... }:
let
  inherit (yen.lib) maybe;
in
{
  yen.kinds.machine.fields = {
    environment = yen.kinds.environment;
    channel = yen.kinds.channel;
    system = yen.kinds.system;
    addr = lib.types.str;
    buildHost = maybe lib.types.str;
    sharedPkgs = yen.lib.opt lib.types.bool false; # reuse one pkgs per (channel, system): platforms/nixos.nix
    trimmedModules = yen.lib.opt lib.types.bool false; # a smaller NixOS base module list: platforms/_modlists.nix
    settings.kernel.channel = maybe (
      yen.helpers.enum [
        "lts"
        "latest"
      ]
    );
  };
}
