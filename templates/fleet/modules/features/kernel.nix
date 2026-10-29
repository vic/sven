# A cascade: host, then its environment, then the environment's base. Data queries, no merge.
{ yen, ... }:
{
  yen.aspects.kernel = {
    at = yen.kinds.host;
    nixos =
      {
        host,
        environment,
        pkgs,
        ...
      }:
      let
        k = yen.lib.cascade [ "settings" "kernel" "channel" ] [ host environment environment.base ];
      in
      {
        boot.kernelPackages = if k == "lts" then pkgs.linuxPackages else pkgs.linuxPackages_latest;
      };
  };
  yen.aspects.facter = {
    at = yen.kinds.host;
    nixos =
      { host, lib, ... }:
      let
        r = ../../facter + "/${host.name}.json";
      in
      lib.optionalAttrs (builtins.pathExists r) { hardware.facter.reportPath = r; };
  };
}
