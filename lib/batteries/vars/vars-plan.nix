#: lib.batteries.vars.vars-plan :: { from; machines; recipientsOf; } -> out value -- the clan vars plan per machine: files, recipients, order
# the clan vars plan per machine, the value of the generators sink's `out` key: the secret files that reach the
# machine with their path (`neededFor = "users"` goes to secrets-for-users), its recipients, and the order to
# generate in (dependencies first). `deploy = false` files never reach the machine.
#   out = clan.vars-plan { from = yen.kinds.fleet.sinks.generators; machines = [ "lb" ]; recipientsOf = m: …; };
{
  from,
  machines,
  recipientsOf,
}:
{ sinks, ... }:
let
  b = builtins;
  graphs = import ../../graphs.nix;
  generators = sinks.${from.__sink};
  pathOf =
    gen: file: f:
    "/run/${
      if f.neededFor or "services" == "users" then "secrets-for-users" else "secrets"
    }/vars/${gen}/${file}";
  planOf =
    m:
    let
      mine = b.filter (g: b.elem m g.machines) (b.attrValues generators);
      byName = b.listToAttrs (
        map (g: {
          inherit (g) name;
          value = g;
        }) mine
      );
      t = graphs.topo (b.mapAttrs (_: g: b.filter (d: byName ? ${d}) (g.dependencies or [ ])) byName);
    in
    {
      files = b.concatMap (
        g:
        map
          (f: {
            generator = g.name;
            file = f;
            path = pathOf g.name f g.files.${f};
            neededForUsers = g.files.${f}.neededFor or null == "users";
          })
          (
            b.filter (f: (g.files.${f}.secret or true) && (g.files.${f}.deploy or true)) (
              b.attrNames (g.files or { })
            )
          )
      ) mine;
      recipients = recipientsOf m;
      order = if t.ok then map (n: byName.${n}) t.order else [ ];
    };
in
{
  varsPlan = b.listToAttrs (
    map (m: {
      name = m;
      value = planOf m;
    }) machines
  );
}
