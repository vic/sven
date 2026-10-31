# Stored queries, labels and valid time for agents.
# - `yen.queries.<name> = { params; answer; }`: named questions with typed parameters; an agent lists them (`queries`)
#   and calls `ask name args`; a fleet name is a ref (from JSON: { kind; name; }).
# - `yen.labels`: trust by file path prefix. Content declared under modules/agent/ is trust 1 (written by agents),
#   the rest trust 3. `floor 3` lists every routed element an agent-written aspect gives.
# - valid time: a machine can have `validTo`; `retire-notice` marks machines past it at the fleet's review date.
{ yen, lib, ... }:
{
  yen.queries = {
    hostsIn = {
      params.env = yen.kinds.environment;
      answer =
        { env, result }:
        map (s: s.name) (
          lib.filter (yen.lib.holds (
            yen.lib.all [
              yen.kinds.host
              (yen.lib.within env)
            ]
          )) result.scopes
        );
    };
    aspectsOn = {
      params.host = yen.kinds.host;
      answer =
        { host, result }:
        let
          s = lib.findFirst (yen.lib.same host) null result.scopes;
        in
        if s == null then [ ] else lib.filter (n: result.active.${n}.${s.id}) (lib.attrNames result.active);
    };
    errorsBy = {
      params.code = yen.lib.maybe (yen.lib.is builtins.isString); # an error code is data, not a fleet name
      answer = { code, result }: lib.filter (e: code == null || e.code == code) result.errors;
    };
    # install order: in an assembly, each client machine waits for the servers (yen.lib.graphs.layers)
    installOrder = {
      params.assembly = yen.kinds.assembly;
      answer =
        { assembly, result }:
        let
          ms = lib.filter (
            s: yen.lib.holds yen.kinds.member s && yen.lib.same s.assembly assembly
          ) result.scopes;
          role =
            rl: lib.unique (map (s: { inherit (s.parent) kind name; }) (lib.filter (s: s.role == rl) ms));
          servers = role "server";
          g = yen.lib.graphs.of (role "client" ++ servers) (
            m: if lib.any (yen.lib.same m) servers then [ ] else servers
          );
        in
        map (map (m: m.name)) (yen.lib.graphs.layers g);
    };
  };
  yen.labels = {
    "modules/" = {
      trust = 3;
    };
    "agent/" = {
      trust = 1;
    };
  };

  yen.kinds.machine.fields.validTo = yen.lib.opt (yen.helpers.listOf lib.types.str) [ ];
  yen.host.web-2.validTo = [ "2026-11-01" ];
  yen.aspects.retire-notice = {
    at = yen.lib.all [
      yen.kinds.host
      (s: s.validTo != [ ])
      (yen.lib.not (s: yen.lib.validAt "2026-11-15" (s // { validTo = lib.head s.validTo; })))
    ];
    nixos.environment.etc."yen/retired".text = "past validTo at the review date 2026-11-15";
  };
}
