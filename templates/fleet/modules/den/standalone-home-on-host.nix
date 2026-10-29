# den#739: Den cannot pipe host data (a quirk) to a standalone home `tux@igloo`, only to a home-manager module home.
# In yen, where a scope lives (spawns) and what it builds (its sink's `out`) are separate. The home `alice@stage`
# lives under host stage, so it reads stage's `monitor` sink like any child, and still builds a standalone
# `homeConfigurations."alice@stage"`.
{ yen, lib, ... }:
let
  inherit (yen.lib) same maybe;
in
{
  yen.kinds.home.fields.on = maybe yen.kinds.host;
  yen.kinds.host.spawns.home = s: lib.filterAttrs (_: h: same h.on s) yen.home;
  yen.kinds.host.sinks.monitor.reduce = yen.lib.reduce.merge;
  yen.kinds.home.sinks.os = { }; # a wall: the home's users give `os` here, and nothing reads it, so stage's NixOS stays untouched
  yen.home."alice@stage" = {
    user = yen.user.alice;
    channel = yen.channel.edge;
    system = yen.system.x86_64-linux;
    on = yen.host.stage;
  };
  yen.aspects.stage-monitor = {
    at = yen.host.stage;
    monitor = {
      resolution = "2560x1440";
      scale = 1.5;
    };
  };
  yen.aspects.host-config-env = {
    # Den #713 / osConfig: a home reads its host's REALIZED config through `out`, lazily
    at = yen.lib.all [
      yen.kinds.user
      (yen.lib.within yen.kinds.home)
      (yen.lib.within yen.kinds.host)
    ];
    homeManager =
      { host, out, ... }:
      {
        home.sessionVariables.HOST_DESKTOP =
          if out.nixosConfigurations.${host.name}.config.services.xserver.enable then "yes" else "no";
      };
  };
  yen.aspects.monitor-env = {
    at = yen.lib.all [
      yen.kinds.user
      (yen.lib.within yen.kinds.home)
    ];
    homeManager =
      {
        monitor ? null,
        ...
      }:
      lib.optionalAttrs (monitor != null) { home.sessionVariables.MONITORRES = monitor.resolution; };
  };
}
