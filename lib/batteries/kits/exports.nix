#: lib.batteries.kits.exports :: { isMember; machineOf ? ; } -> reduce -- each member writes only its own exports; other scopes override one entry
# a reduce for kit exports: each member writes only under its own (assembly, role, machine), and only the keys its
# kit lists in `exports`. An element from any other scope is the owner's override of one entry: refs
# `{ assembly; role; machine; value; }`. Read the value with a filter on refs (`yen.lib.same`).
#   yen.kinds.fleet.sinks.exports.reduce = kits.exports { isMember = yen.lib.holds yen.kinds.member; };
{
  isMember,
  machineOf ? e: e.from.parent,
}:
es:
let
  b = builtins;
  same = x: y: x.kind or null == y.kind or null && x.name == y.name;
  overrides = map (e: e.value) (b.filter (e: !isMember e.from) es);
  own = map (e: {
    inherit (e.from) assembly kit role;
    machine = machineOf e;
    inherit (e) value;
  }) (b.filter (e: isMember e.from) es);
  hit = x: o: same o.assembly x.assembly && o.role == x.role && same o.machine x.machine;
  over =
    x:
    let
      hits = b.filter (hit x) overrides;
    in
    if hits == [ ] then null else b.head hits;
  where = x: "${x.assembly.name}.${x.role}@${x.machine.name}";
in
{
  value = map (
    x:
    let
      o = over x;
    in
    if o != null then x // { inherit (o) value; } else x
  ) own;
  errors = b.concatMap (
    x:
    map (k: { error = "kits: ${where x}: kit ${x.kit.name} does not export ${k}"; }) (
      b.filter (k: !b.elem k (x.kit.exports or [ ])) (b.attrNames x.value)
    )
  ) own;
}
