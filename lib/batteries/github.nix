# GitHub Actions: a YAML writer and workflow files from a sink of jobs. Builtins only.
#   yen.kinds.repo.sinks.jobs = { reduce = yen.lib.reduce.merge;
#     files = github.workflow { from = yen.kinds.repo.sinks.jobs; path = ".github/workflows/test.yml";
#       doc = { name = "test"; on.push = { }; }; }; };
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
{
  yaml = yaml 0;

  # a workflow file from the jobs of sink `from` (reduce merge: one attr per job). `header` reads the job names.
  workflow =
    {
      from,
      path,
      doc,
      header ? _: "",
    }:
    { sinks, ... }:
    let
      jobs = sinks.${from.__sink};
    in
    {
      files.file.${path}.text = header (b.attrNames jobs) + yaml 0 (doc // { inherit jobs; });
    };
}
