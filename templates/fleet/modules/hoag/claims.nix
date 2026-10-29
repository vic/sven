# den-hoag productions: claim / provide with the reverse read (who claims me). Apps claim databases; the database host
# reads every claim aimed at it and provides them; each app reads its provider's answer. Data that points both ways is two
# facts, not a cycle: laziness, no strata.
{ yen, lib, ... }:
let
  inherit (yen.lib) same;
in
{
  yen.kinds.machine.fields.dbOn = yen.lib.maybe yen.kinds.host;
  yen.host.web-1.dbOn = yen.host.lb;
  yen.host.web-2.dbOn = yen.host.lb;
  yen.host.stage.dbOn = yen.host.stage;
  yen.kinds.fleet.sinks.db-claims.reduce = yen.lib.reduce.entries;
  yen.aspects.db-claim = {
    at = yen.lib.all [
      yen.kinds.host
      (s: s.dbOn != null && !s.minimal)
    ];
    db-claims =
      { host, ... }:
      {
        db = "app_${lib.replaceStrings [ "-" ] [ "_" ] host.name}";
        on = host.dbOn;
      };
  };
  yen.aspects.db-provide = {
    at = yen.lib.all [
      yen.kinds.host
      (s: !s.minimal)
    ];
    nixos =
      { host, db-claims, ... }:
      let
        mine = lib.filter (e: same e.value.on host) db-claims;
      in
      # the reverse read: who claims me
      lib.optionalAttrs (mine != [ ]) {
        services.postgresql = {
          enable = true;
          ensureDatabases = map (e: e.value.db) mine;
        };
      };
  };
  yen.aspects.db-client = {
    at = yen.lib.all [
      yen.kinds.host
      (s: s.dbOn != null && !s.minimal)
    ];
    nixos =
      { host, ... }:
      {
        environment.etc."app/database-url".text = "postgres://${host.dbOn.addr}/app_${
          lib.replaceStrings [ "-" ] [ "_" ] host.name
        }";
      };
  };
}
