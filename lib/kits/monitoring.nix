#: lib.kits.monitoring :: module -- one prometheus server reads the scrape target of every exporter of its assembly
# The exporter runs the node exporter on `port` and exports its target; the server turns every exporter of its own
# assembly into one `services.prometheus.scrapeConfigs` job. Needs a machine field `addr`.
#   imports = [ inputs.yen.lib.kits.monitoring ];
{ yen, lib, ... }:
let
  inherit (yen.lib) all same;
  member =
    role:
    all [
      yen.kinds.member
      (s: same (s.kit or null) yen.kit.monitoring && s.role == role)
    ];
in
{
  yen.kit.monitoring = {
    roles = {
      server = { };
      exporter.interface.port = {
        type = lib.types.port;
        default = 9100;
      };
    };
    constraints.roles.server = {
      min = 1;
      max = 1;
    };
    exports = [ "target" ];
  };
  yen.aspects.monitoring-exporter = {
    at = member "exporter";
    exports =
      { scope, member, ... }:
      {
        target = "${scope.parent.addr}:${toString member.settings.port}";
      };
    nixos =
      { member, ... }:
      {
        services.prometheus.exporters.node = {
          enable = true;
          inherit (member.settings) port;
        };
      };
  };
  yen.aspects.monitoring-server = {
    at = member "server";
    nixos =
      { member, exports, ... }:
      {
        services.prometheus.enable = true;
        services.prometheus.scrapeConfigs = map (e: {
          job_name = e.machine.name;
          static_configs = [ { targets = [ e.value.target ]; } ];
        }) (lib.filter (e: same e.assembly member.assembly && e.role == "exporter") exports);
      };
  };
}
