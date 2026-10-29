# Ground rules { head; pos; neg; }, one set per host. You ground them with Nix.
{ yen, lib, ... }:
let
  D = yen.lib.datalog;
  hosts = lib.attrValues yen.host;
  rules =
    lib.concatMap (
      h:
      let
        n = h.name;
      in
      lib.optional h.web { head = "web:${n}"; }
      ++ lib.optional (!h.maintenance) { head = "up:${n}"; }
      ++ [
        {
          head = "serves:${n}";
          pos = [ "web:${n}" ];
          neg = [ "drained:${n}" ];
        }
      ]
      ++ map (d: {
        head = "drained:${n}";
        neg = [ "up:${d.name}" ];
      }) h.dependsOn
    ) hosts
    # a choice: exactly one primary database, and the policy does not say which
    ++ [
      {
        head = "primary:db-1";
        neg = [ "primary:db-2" ];
      }
      {
        head = "primary:db-2";
        neg = [ "primary:db-1" ];
      }
    ];
  model = D.wfs rules;
in
{
  yen.aspects.serving = {
    at = yen.kinds.fleet;
    out.serving = {
      serves = map (lib.removePrefix "serves:") (lib.filter (lib.hasPrefix "serves:") model.true);
      undefined = model.undefined; # well-founded: the choice stays open
      choices = map (m: lib.filter (lib.hasPrefix "primary:") m) (D.stable rules); # stable models: each choice
      whyNot = D.whyNot rules model "serves:web-2";
      proof = D.proof rules model "serves:web-1";
    };
  };
}
