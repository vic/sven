# a workflow file from the jobs of sink `from` (reduce merge: one attr per job). `header` reads the job names.
#   yen.kinds.repo.sinks.jobs = { reduce = yen.lib.reduce.merge;
#     files = github.workflow { from = yen.kinds.repo.sinks.jobs; path = ".github/workflows/test.yml";
#       doc = { name = "test"; on.push = { }; }; }; };
let
  yaml = import ./yaml.nix;
in
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
  files.file.${path}.text = header (builtins.attrNames jobs) + yaml (doc // { inherit jobs; });
}
