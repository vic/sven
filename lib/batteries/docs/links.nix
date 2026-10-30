# a reduce: elements `{ name; file; needle; text; }` become `{ <name> = "[`text`](file#L<n>)"; }`, where <n> is the first
# line of `root + "/${file}"` that contains `needle`. The line is found at eval time, so links follow edits; a needle
# that is gone is an error record.
#   sinks.links.reduce = docs.links { root = ./.; };   then read `sinks.links.<name>`
{
  root,
  base ? "",
}:
es:
let
  b = builtins;
  lineOf =
    file: needle:
    let
      lines = b.filter b.isString (b.split "\n" (b.readFile (root + "/${file}")));
      has = l: b.replaceStrings [ needle ] [ "" ] l != l; # literal substring, no regex
      hits = b.filter (i: has (b.elemAt lines i)) (b.genList (i: i) (b.length lines));
    in
    if hits == [ ] then null else b.head hits + 1;
  found = map (e: e.value // { line = lineOf e.value.file e.value.needle; }) es;
  ok = b.filter (l: l.line != null) found;
in
{
  value = b.listToAttrs (
    map (l: {
      inherit (l) name;
      value = "[`${l.text}`](${base}${l.file}#L${toString l.line})";
    }) ok
  );
  errors = map (l: {
    error = "link ${l.name}: `${l.needle}` not found in ${l.file}";
    code = "link-gone";
    got = l.needle;
  }) (b.filter (l: l.line == null) found);
}
