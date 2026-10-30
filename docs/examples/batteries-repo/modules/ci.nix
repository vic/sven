# CI: jobs from any aspect become .github/workflows/ci.yml; a matrix of targets becomes ci.json.
{ yen, ... }:
let
  inherit (yen.lib.batteries) files github;
in
{
  yen.kinds.repo.sinks = {
    jobs = {
      reduce = yen.lib.reduce.merge;
      files = github.workflow {
        from = yen.kinds.repo.sinks.jobs;
        path = ".github/workflows/ci.yml";
        doc = {
          name = "ci";
          on.push = { };
        };
        header = jobs: files.comment "ci.yml" "Generated. Jobs: ${toString jobs}";
      };
    };
    targets = {
      reduce = yen.lib.reduce.merge;
      files = files.json {
        from = yen.kinds.repo.sinks.targets;
        path = "ci.json";
        value = builtins.attrValues;
      };
    };
  };
  yen.aspects.check-job = {
    at = yen.kinds.repo;
    jobs.check = {
      runs-on = "ubuntu-latest";
      steps = [
        { uses = "actions/checkout@v4"; }
        { run = "nix flake check"; }
      ];
    };
  };
  yen.aspects.shell-target = {
    at = yen.kinds.system;
    targets =
      { scope, ... }:
      {
        ${scope.name} = "devShells.${scope.name}.default";
      };
  };
}
