# Written once, for every machine: options that NixOS and nix-darwin share.
{ yen, ... }:
{
  yen.aspects.shared = {
    at = [
      yen.kinds.host
      yen.kinds.mac
    ];
    os =
      { scope, pkgs, ... }:
      {
        networking.hostName = scope.name;
        environment.systemPackages = [ pkgs.git ];
        nix.settings.experimental-features = [
          "nix-command"
          "flakes"
        ];
      };
  };
}
