# A serving policy in Datalog with negation. Nix grounds the rules from fleet data (one per host); the well-founded
# model decides. A host serves when it runs nginx and is not drained; a host is drained when it is in maintenance
# or when the host it depends on is down. The db primary is a choice: two candidates, each primary unless the other
# is (an even cycle). The well-founded model leaves both undefined; `stable` gives the two choices, and the fleet
# takes the first. Any other undefined atom is an error: a policy must decide.
{ yen, lib, ... }:
let
  D = yen.lib.datalog;
  whole.graph = true; # a tree request: the whole fleet (host data, scopes, aspects)
  # the policy is a function of the whole fleet
  policy =
    yen:
    let
      hosts = lib.filterAttrs (_: h: h ? addr && !(h.minimal or false)) yen.host;
      candidates = [
        "lb"
        "web-1"
      ];
      rules =
        lib.concatLists (
          lib.mapAttrsToList (
            n: h:
            [
              {
                head = "serves:${n}";
                pos = [ "web:${n}" ];
                neg = [ "drained:${n}" ];
              }
              {
                head = "drained:${n}";
                pos = [ "maintenance:${n}" ];
              }
            ]
            ++ map (d: {
              head = "drained:${n}";
              neg = [ "up:${d.name}" ];
            }) (h.dependsOn or [ ])
            ++ lib.optional (!h.maintenance) { head = "up:${n}"; }
            ++ lib.optional h.maintenance { head = "maintenance:${n}"; }
            ++ lib.optional (lib.any (yen.lib.holds yen.aspects.nginx) (yen.lib.scopesOf h)) {
              head = "web:${n}";
            }
          ) hosts
        ) # a host with no scope (bad data) runs nothing
        ++ map (c: {
          head = "primary:${c}";
          neg = map (o: "primary:${o}") (lib.remove c candidates);
        }) candidates;
      model = D.wfs rules;
      models = D.stable rules;
      choice = if models == [ ] then [ ] else lib.head models;
      pick = prefix: map (lib.removePrefix prefix) (lib.filter (lib.hasPrefix prefix) choice);
    in
    {
      inherit
        hosts
        rules
        model
        models
        pick
        ;
    };
  # a component on the policy: it asks the tree for the whole fleet
  withPolicy = f: {
    cycle =
      { tree, ... }:
      {
        tree = [ whole ];
      }
      // f (policy (lib.head (tree.select whole)));
  };
in
{
  yen.kinds.machine.fields.maintenance = yen.lib.opt lib.types.bool false;
  # for agents: why a host does not serve, and whether the db primary is decided (judge: supported, refuted, both, neither, unknown)
  yen.aspects.serving-explain = {
    at = yen.fleet.main;
  }
  // withPolicy (p: {
    out.serving = {
      whyNot = lib.genAttrs (lib.attrNames p.hosts) (n: D.whyNot p.rules p.model "serves:${n}");
      primary = D.judge p.rules "primary:lb" "primary:web-1";
    };
  });
  yen.aspects.serving-policy = {
    at = yen.host.lb;
  }
  // withPolicy (p: {
    nixos.environment.etc = {
      "lb/serving".text = lib.concatStringsSep " " (p.pick "serves:");
      "db/primary".text = lib.concatStringsSep " " (p.pick "primary:");
      "lb/why-web-1".text = builtins.toJSON (D.why p.rules p.model "serves:web-1");
      "lb/proof-web-1".text = builtins.toJSON (D.proof p.rules p.model "serves:web-1");
    };
    errors = [
      (
        map (a: "serving policy: ${a} is undefined") (
          lib.filter (a: !lib.hasPrefix "primary:" a) p.model.undefined
        )
        ++ lib.optional (p.models == [ ]) "serving policy: no stable model (an odd cycle through not)"
      )
    ];
  });
}
