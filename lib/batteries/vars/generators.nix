#: lib.batteries.vars.generators :: { machineOf; } -> reduce -- clan vars generators, shared or per machine, with dependency checks
# a reduce for clan vars generators: elements `{ name; files; share ? false; dependencies ? [ ]; }` (null gives
# nothing). A shared generator is one for every machine that gives it; any other is keyed name@machine. A dependency
# must name a generator the same machine has, or a shared one. value: key -> generator // { machines; }.
#   yen.kinds.fleet.sinks.generators.reduce = clan.generators { machineOf = s: if holds yen.kinds.member s then s.parent else s; };
{ machineOf }:
es:
let
  b = builtins;
  keyOf = g: if g.share or false then g.name else "${g.name}@${g.machine}";
  unique = b.foldl' (acc: x: if b.elem x acc then acc else acc ++ [ x ]) [ ];
  gs = map (e: e.value // { machine = (machineOf e.from).name; }) (b.filter (e: e.value != null) es);
  byKey = b.mapAttrs (
    _: xs: b.removeAttrs (b.head xs) [ "machine" ] // { machines = unique (map (g: g.machine) xs); }
  ) (b.groupBy keyOf gs);
in
{
  value = byKey;
  errors = b.concatMap (
    g:
    map (d: { error = "vars: generator ${keyOf g} depends on ${d}, which ${g.machine} has not"; }) (
      b.filter (d: !(byKey ? ${d} || byKey ? "${d}@${g.machine}")) (g.dependencies or [ ])
    )
  ) gs;
}
