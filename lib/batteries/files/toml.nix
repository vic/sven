#: lib.batteries.files.toml :: { inline ? ; } -> value -> string -- TOML text from a Nix value
# TOML text from a Nix value, builtins only. Top-level attrsets, and attrsets of attrsets, become [tables] (nested:
# [a.b]); other attrsets are inline tables. `inline` keeps the given table paths inline.
#   files.toml { } { project.name = "app"; profiles.default.API_KEY = { description = "key"; }; }
{
  inline ? [ ],
}:
let
  b = builtins;
  bare = k: b.match "[A-Za-z0-9_-]+" k != null;
  key = k: if bare k then k else b.toJSON k;
  join = b.concatStringsSep;
  value =
    v:
    if b.isAttrs v then
      "{ ${join ", " (map (k: "${key k} = ${value v.${k}}") (b.attrNames v))} }"
    else if b.isList v then
      "[${join ", " (map value v)}]"
    else
      b.toJSON v;
  # a table: its scalar and inline keys first, then its sub-tables
  isTable =
    path: v:
    b.isAttrs v
    && !b.elem (join "." path) inline
    && (b.length path == 1 || b.any b.isAttrs (b.attrValues v));
  table =
    path: t:
    let
      ks = b.attrNames t;
      subs = b.filter (k: isTable (path ++ [ k ]) t.${k}) ks;
      own = b.filter (k: !b.elem k subs) ks;
      head = if path == [ ] || own == [ ] && subs != [ ] then "" else "[${join "." (map key path)}]\n";
      body = join "" (map (k: "${key k} = ${value t.${k}}\n") own);
    in
    join "\n" (b.filter (s: s != "") ([ (head + body) ] ++ map (k: table (path ++ [ k ]) t.${k}) subs));
in
v: table [ ] v
