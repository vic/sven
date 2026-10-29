# The old common.nix and the mkHost helper, as aspects at every host.
{ yen, inputs, ... }:
{
  yen.aspects.common = {
    at = yen.kinds.host;
    nixos =
      { host, pkgs, ... }:
      {
        networking.hostName = host.name;
        boot.loader.systemd-boot.enable = true;
        time.timeZone = "UTC";
        services.openssh.enable = true;
        environment.systemPackages = [ pkgs.git ];
        system.stateVersion = "25.05";
      };
  };
  yen.aspects.home-manager = {
    at = yen.lib.has yen.kinds.user; # only hosts with users
    nixos = {
      imports = [ inputs.home-manager.nixosModules.home-manager ];
      home-manager.useGlobalPkgs = true;
    };
  };
}
