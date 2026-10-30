#: lib.batteries.docs.vocabulary :: { what; names; lines; } -> [ error ] -- a doc line for every live name; a missing or stale line is an error record
# a doc line for every live name: the value of an aspect's `errors` key. A live name with no line, or a line that
# names nothing live, is an error record, so the doc never drifts from the fleet.
#   errors = docs.vocabulary { what = "kinds"; names = builtins.attrNames yen.kinds; lines = (import ./vocab.nix).kinds; };
{
  what,
  names,
  lines,
}:
let
  b = builtins;
  missing = b.filter (n: !(lines ? ${n})) names;
  stale = b.filter (n: !(b.elem n names)) (b.attrNames lines);
  err = code: n: msg: {
    error = "${what} `${n}`: ${msg}";
    inherit code;
    got = n;
  };
in
map (n: err "doc-missing" n "a live name with no doc line") missing
++ map (n: err "doc-stale" n "a doc line that names nothing live") stale
