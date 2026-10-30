# a reduce for clan exports: each member writes only under its own key SERVICE:INSTANCE:ROLE:MACHINE; an element
# from any other scope is the owner's override of one entry (it names the key). A key a service does not list in
# `services.<service>.exports` is an error. Read the value with a filter (clan selectExports).
#   yen.kinds.fleet.sinks.exports.reduce = clan.exports { inherit services; isMember = yen.lib.holds yen.kinds.member; };
{
  services,
  isMember,
  machineOf ? e: e.from.parent.name,
}:
es:
let
  b = builtins;
  overrides = map (e: e.value) (b.filter (e: !isMember e.from) es);
  keyOf = x: "${x.service}:${x.instance}:${x.role}:${x.machine}";
  own = map (e: {
    inherit (e.from) service instance role;
    machine = machineOf e;
    inherit (e) value;
  }) (b.filter (e: isMember e.from) es);
  over =
    x:
    let
      hits = b.filter (o: keyOf o == keyOf x) overrides;
    in
    if hits == [ ] then null else b.head hits;
  allowed = x: services.${x.service}.exports or [ ];
in
{
  value = map (x: if over x != null then x // { inherit (over x) value; } else x) own;
  errors = b.concatMap (
    x:
    map (k: { error = "clan: ${keyOf x}: service ${x.service} does not export ${k}"; }) (
      b.filter (k: !b.elem k (allowed x)) (b.attrNames x.value)
    )
  ) own;
}
