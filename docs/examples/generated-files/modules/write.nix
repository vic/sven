# README.md and the CI workflow, generated from fleet data by github:sini/files.
{ sven, lib, ... }:
let
  hosts = lib.filter (s: s.kind == "host") sven.lib.graph.scopes;
in
{
  sven.aspects.write = {
    at = sven.kinds.fleet;
    files = {
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
    };
  };
}
