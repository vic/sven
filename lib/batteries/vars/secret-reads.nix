# the value of an `errors` key: a public read (`{ machine; generator; file; }` in sink `reads`, reduce entries) of a
# file that is secret on that machine (clan refuses to read secret values at eval time).
#   errors = clan.secret-reads { from = yen.kinds.fleet.sinks.generators; reads = yen.kinds.fleet.sinks.public-reads; };
{ from, reads }:
{ sinks, ... }:
let
  b = builtins;
  generators = b.attrValues sinks.${from.__sink};
in
map (r: "vars: ${r.value.machine} reads ${r.value.generator}/${r.value.file}, a secret file") (
  b.filter (
    r:
    b.any (
      g:
      b.elem r.value.machine g.machines
      && g.name == r.value.generator
      && (g.files.${r.value.file}.secret or true)
    ) generators
  ) sinks.${reads.__sink}
)
