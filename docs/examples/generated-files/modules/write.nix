# README.md and the CI workflow, generated from fleet data by github:sini/files.
{ yen, lib, ... }:
let
  whole.graph = true; # a tree request: the whole fleet
in
{
  yen.aspects.write = {
    at = yen.kinds.fleet;
    cycle =
      { tree, ... }:
      let
        yen = builtins.head (tree.select whole); # the whole fleet, with its data
        hosts = lib.filter (s: yen.lib.holds yen.kinds.host s) yen.lib.graph.scopes;
      in
      {
        tree = [ whole ];
        files = [
          {
            files.file."README.md".text = ''
              # My fleet

              Generated from the fleet. Hosts: ${lib.concatMapStringsSep ", " (s: "`${s.name}`") hosts}.

              ```mermaid
              graph TD
                fleet[main]
              ${lib.concatMapStringsSep "\n" (s: "  fleet --> ${s.name}") hosts}
              ```
            '';
            files.file.".github/workflows/ci.yml".text = ''
              name: ci
              on: [push, pull_request]
              jobs:
                check:
                  runs-on: ubuntu-latest
                  steps:
                    - uses: actions/checkout@v4
                    - uses: DeterminateSystems/nix-installer-action@main
                    - run: nix flake check
            '';
          }
        ];
      };
  };
}
