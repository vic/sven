#: lib.batteries.kits.contract :: { assemblies; machines; holds; } -> [ error ] -- the assembly contract: roles, machine counts, assemblies per kit
# the assembly contract, the value of an `errors` key: the kit is a kit, every role is the kit's and its `at` is a
# predicate, the machine count per role is within the kit's `constraints.roles.<role>.{min,max}`, and at most
# `constraints.maxAssemblies` assemblies use one kit.
#   errors = kits.contract { assemblies = attrValues yen.assembly; machines = attrValues yen.host; inherit (yen.lib) holds; };
{
  assemblies,
  machines,
  holds,
}:
let
  b = builtins;
  inherit (import ./_roles.nix) takes;
  isPredicate = p: b.isFunction p || b.isList p || b.isAttrs p;
  same = x: y: b.isAttrs x && x.kind or null == y.kind or null && x.name or null == y.name or null;
  check =
    a:
    let
      k = a.kit;
      c = k.constraints or { };
      roles = b.attrNames a.roles;
      at = r: a.roles.${r}.at or null;
      known = r: k.roles ? ${r};
      count = r: b.length (b.filter (takes holds a.roles.${r}) machines);
      when = cond: msg: if cond then [ msg ] else [ ];
    in
    if !(b.isAttrs k && k ? roles) then
      [ "kits: assembly ${a.name}: kit is a ${b.typeOf k}, not a kit" ]
    else
      when (roles == [ ]) "kits: assembly ${a.name} has no roles"
      ++ map (r: "kits: assembly ${a.name}: kit ${k.name} has no role ${r}") (
        b.filter (r: !known r) roles
      )
      ++ map (r: "kits: assembly ${a.name} role ${r}: `at` is a ${b.typeOf (at r)}, not a predicate") (
        b.filter (r: !isPredicate (at r)) roles
      )
      ++ b.concatMap (
        r:
        let
          n = count r;
          lim = c.roles.${r} or { };
        in
        when (
          lim ? min && n < lim.min
        ) "kits: assembly ${a.name} role ${r}: ${toString n} machines, at least ${toString lim.min}"
        ++ when (
          lim ? max && n > lim.max
        ) "kits: assembly ${a.name} role ${r}: ${toString n} machines, at most ${toString lim.max}"
      ) (b.filter (r: known r && isPredicate (at r)) roles)
      ++ when (
        c ? maxAssemblies && b.length (b.filter (x: same x.kit k) assemblies) > c.maxAssemblies
      ) "kits: assembly ${a.name}: kit ${k.name} allows ${toString c.maxAssemblies} assemblies";
in
b.concatMap check assemblies
