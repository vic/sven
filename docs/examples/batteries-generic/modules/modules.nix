# eval-modules, configurations, imports: module systems other than yen's, fed by sinks.
{ yen, lib, ... }:
let
  inherit (yen.lib.batteries) eval-modules configurations imports;
in
{
  # each host collects service settings as modules; eval-modules merges them with the module system
  yen.kinds.host.sinks.settings.out = configurations {
    from = yen.kinds.host.sinks.settings;
    output = "settings";
    build =
      _: modules:
      (lib.evalModules {
        modules = [ { freeformType = lib.types.attrsOf lib.types.anything; } ] ++ modules;
      }).config;
  };
  # the same with eval-modules, at the fleet: one report from every host's report module
  yen.kinds.fleet.sinks.report.out = eval-modules {
    from = yen.kinds.fleet.sinks.report;
    inherit lib;
    modules = [ { options.hosts = lib.mkOption { type = lib.types.listOf lib.types.str; }; } ];
    result = e: { report = e.config; };
  };
  # imports: a sink of modules as one module, here for a docs sink
  yen.kinds.fleet.sinks.notes.out =
    { sinks, ... }:
    {
      notes = imports { from = yen.kinds.fleet.sinks.notes; } { inherit sinks; };
    };

  yen.aspects.ssh-settings = {
    at = yen.kinds.host;
    settings.ssh.port = 22;
    report =
      { host, ... }:
      {
        hosts = [ host.name ];
      };
    notes = "note";
  };
  yen.aspects.nas-settings = {
    at = yen.host.nas;
    settings.ssh.ciphers = [ "chacha20" ];
  };
}
