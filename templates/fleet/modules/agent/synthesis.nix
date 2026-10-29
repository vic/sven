# Synthesis an agent can call (stored queries, so `ask` and the MCP server reach them). Each answer is checked
# before it is given: krn finds values that meet the constraints, and a placement is staged against every invariant.
# - freePort { host }          the lowest port in 8080..8099 that no app on the host uses (krn, finite domains)
# - placeDb { host }           the database hosts of the host's own environment (krn, unification over host records)
# - safeHostsFor { aspect; env } the machines of `env` where the aspect can be active with no new error or violation:
#                              each candidate is a change program, validated and staged; refusals come with their reason
{ yen, lib, ... }:
let
  K = yen.lib.krn;
  machinesIn =
    result: env:
    lib.filter (
      s:
      lib.elem s.kind [
        "host"
        "mac"
      ]
      && s.parent.kind == "environment"
      && s.parent.name == env
    ) result.scopes;
in
{
  yen.queries = {
    freePort =
      { host, result }:
      let
        id = (lib.findFirst (s: s.kind == "host" && s.name == host) { id = ""; } result.scopes).id;
        used = lib.concatMap (
          m: lib.attrValues (builtins.fromJSON (m.environment.etc."apps/ports".text or "{}"))
        ) (result.reduced.nixos.${id} or [ ]);
        a = K.run 1 (q: [ (K.infd [ q ] 8080 8099) ] ++ map (p: K.neqfd q p) used ++ [ (K.label [ q ]) ]);
      in
      if a == [ ] then
        {
          error = "no free port on ${host} in 8080..8099";
          inherit used;
        }
      else
        {
          port = lib.head a;
          inherit used;
        };
    placeDb =
      { host, result }:
      let
        rows = map (s: {
          name = s.name;
          env = s.parent.name;
          db = s.dbRole or false;
        }) (lib.filter (s: s.kind == "host" && s.parent.kind == "environment") result.scopes);
      in
      K.runAll (
        q:
        K.fresh (
          {
            env,
            d,
            own,
          }:
          [
            (K.facto rows {
              name = host;
              inherit env;
              db = own;
            })
            (K.facto rows {
              name = d;
              inherit env;
              db = true;
            })
            (K.eq q d)
          ]
        )
      );
    safeHostsFor =
      {
        aspect,
        env,
        result,
      }:
      let
        try =
          s:
          yen.lib.program.dryRun {
            base = result.root;
            inherit result;
            prog = [
              {
                op = "place";
                inherit aspect;
                inherit (s) kind name;
              }
            ];
          };
        tried = map (s: {
          inherit (s) name;
          d = try s;
        }) (machinesIn result env);
      in
      {
        safe = map (x: x.name) (lib.filter (x: x.d.ok) tried);
        refused = lib.listToAttrs (
          map (x: {
            name = x.name;
            value = x.d.violations or [ ] ++ map (e: e.error) (x.d.errors or [ ]);
          }) (lib.filter (x: !x.d.ok) tried)
        );
      };
  };
}
