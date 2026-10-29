# Stored queries, labels and valid time for agents.
# - `yen.queries.<name>`: named questions with parameters; an agent lists them (`queries`) and calls `ask name args`.
# - `yen.labels`: trust by file path prefix. Content declared under modules/agent/ is trust 1 (written by agents),
#   the rest trust 3. `floor 3` lists every routed element an agent-written aspect gives.
# - valid time: a machine can have `validTo`; `retire-notice` marks machines past it at the fleet's review date.
{ yen, lib, ... }:
{
  yen.queries = {
    hostsIn =
      { env, result }:
      map (s: s.name) (
        lib.filter (s: s.kind == "host" && lib.hasInfix "/environment:${env}/" s.id) result.scopes
      );
    aspectsOn =
      { host, result }:
      let
        s = lib.findFirst (x: x.kind == "host" && x.name == host) null result.scopes;
      in
      if s == null then [ ] else lib.filter (n: result.active.${n}.${s.id}) (lib.attrNames result.active);
    errorsBy =
      {
        code ? null,
        result,
      }:
      lib.filter (e: code == null || e.code == code) result.errors;
    # clan install order: in a service instance, each client machine waits for the servers (yen.lib.graphs.layers)
    installOrder =
      { instance, result }:
      let
        ms = lib.filter (s: s.kind == "member" && lib.hasPrefix "${instance}." s.name) result.scopes;
        role = rl: lib.unique (map (s: s.parent.name) (lib.filter (s: lib.hasSuffix ".${rl}" s.name) ms));
        servers = role "server";
      in
      yen.lib.graphs.layers (
        lib.genAttrs (role "client" ++ servers) (m: if lib.elem m servers then [ ] else servers)
      );
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
