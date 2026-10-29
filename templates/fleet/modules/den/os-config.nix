# Den/home-manager `osConfig`: each host gives its realized config to an `osConfig` sink. A homeManager module
# names `osConfig` like any sink arg; `pkgs` stays open, so home-manager fills its own pkgs. The same aspect
# works in a user nested in a host's NixOS and in a standalone home that lives under a host.
{ sven, ... }:
{
  sven.kinds.host.sinks.osConfig.reduce = sven.lib.reduce.one;
  sven.aspects.os-config = {
    at = sven.kinds.host;
    osConfig = { host, out, ... }: out.nixosConfigurations.${host.name}.config; # lazy: read only when a module asks
  };
  sven.aspects.editors = {
    at = sven.lib.all [
      sven.kinds.user
      (sven.lib.within sven.kinds.host)
    ];
    homeManager =
      { osConfig, pkgs, ... }:
      {
        home.sessionVariables.EDITOR_HOST = osConfig.networking.hostName;
        home.packages = [ pkgs.nano ];
      };
  };
}
