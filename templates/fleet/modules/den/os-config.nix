# Den/home-manager `osConfig`: each host gives its realized config to an `osConfig` sink. A homeManager module
# names `osConfig` like any sink arg; `pkgs` stays open, so home-manager fills its own pkgs. The same aspect
# works in a user nested in a host's NixOS and in a standalone home that lives under a host.
{ yen, ... }:
{
  yen.kinds.host.sinks.osConfig.reduce = yen.lib.reduce.one;
  yen.aspects.os-config = {
    at = yen.kinds.host;
    osConfig = { host, out, ... }: out.nixosConfigurations.${host.name}.config; # lazy: read only when a module asks
  };
  yen.aspects.editors = {
    at = yen.lib.all [
      yen.kinds.user
      (yen.lib.within yen.kinds.host)
    ];
    homeManager =
      { osConfig, pkgs, ... }:
      {
        home.sessionVariables.EDITOR_HOST = osConfig.networking.hostName;
        home.packages = [ pkgs.nano ];
      };
  };
}
