# YAML for GitHub Actions: block style, `|` for multi-line strings, JSON-quoted scalars and keys. Builtins only.
let
  b = builtins;
  spaces = n: b.concatStringsSep "" (b.genList (_: " ") n);
  lines = s: b.filter b.isString (b.split "\n" s);
  hasNewline = s: b.length (b.split "\n" s) > 1;
  # lib.removeSuffix "\n"
  dropNewline =
    s:
    let
      n = b.stringLength s;
    in
    if n > 0 && b.substring (n - 1) 1 s == "\n" then b.substring 0 (n - 1) s else s;
  # block style, `|` for multi-line strings, JSON-quoted scalars and keys
  yaml =
    ind: v:
    if b.isAttrs v then
      b.concatStringsSep "" (map (k: "${spaces ind}${b.toJSON k}:" + item ind v.${k}) (b.attrNames v))
    else
      b.concatStringsSep "" (
        map (x: "${spaces ind}-" + (if b.isAttrs x then "\n" + yaml (ind + 2) x else item ind x)) v
      );
  item =
    ind: x:
    if b.isAttrs x then
      (if x == { } then " {}\n" else "\n" + yaml (ind + 2) x)
    else if b.isList x then
      "\n" + yaml (ind + 2) x
    else if b.isString x && hasNewline x then
      " |\n" + b.concatStringsSep "" (map (l: spaces (ind + 2) + l + "\n") (lines (dropNewline x)))
    else
      " ${b.toJSON x}\n";
in
yaml 0
