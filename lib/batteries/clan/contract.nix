# clan's instance contract, the value of an `errors` key: a known service, known roles, at least one role, the
# machine count per role within `constraints.roles.<role>.{min,max}`, at most `constraints.maxInstances`.
#   errors = clan.contract { inherit instances services; machines = attrValues yen.host; labelsOf = …; };
{
  instances,
  services,
  machines,
  labelsOf ? m: m.labels or [ ],
}:
let
  b = builtins;
  inherit (import ./_roles.nix) roleHas;
  check =
    n:
    let
      i = instances.${n};
      svc = services.${i.module} or null;
      c = svc.constraints or { };
      count = r: b.length (b.filter (roleHas labelsOf i.roles.${r}) machines);
      roles = b.attrNames i.roles;
      known = b.filter (r: svc.roles ? ${r}) roles;
      when = cond: msg: if cond then [ msg ] else [ ];
    in
    if svc == null then
      [ "clan: instance ${n} uses unknown service ${i.module}" ]
    else
      when (i.roles == { }) "clan: instance ${n} has no roles"
      ++ map (r: "clan: instance ${n}: service ${i.module} has no role ${r}") (
        b.filter (r: !(svc.roles ? ${r})) roles
      )
      ++ b.concatMap (
        r:
        let
          k = count r;
          lim = c.roles.${r} or { };
        in
        when (
          lim ? min && k < lim.min
        ) "clan: instance ${n} role ${r}: ${toString k} machines, at least ${toString lim.min}"
        ++ when (
          lim ? max && k > lim.max
        ) "clan: instance ${n} role ${r}: ${toString k} machines, at most ${toString lim.max}"
      ) known
      ++ when (
        c ? maxInstances
        &&
          b.length (b.filter (j: instances.${j}.module == i.module) (b.attrNames instances)) > c.maxInstances
      ) "clan: instance ${n}: service ${i.module} allows ${toString c.maxInstances} instances";
in
b.concatMap check (b.attrNames instances)
