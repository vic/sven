# `nix develop` in docs/: a numtide/devshell. Its commands are a sink: each aspect gives the commands of its part.
# Every command runs from the repo root, whatever the directory: `nix develop ./docs` from the root, or `nix develop` in docs/.
# CI runs these commands and nothing else (modules/ci.nix), so every CI step runs the same way locally.
{
  sven,
  lib,
  inputs,
  ...
}:
let
  systems = [
    "x86_64-linux"
    "aarch64-linux"
    "aarch64-darwin"
  ];
  # tools are called by name, so a command's text is the same on every system
  cmd = category: name: help: command: {
    inherit category name help;
    command = "set -eu; cd \"$(git rev-parse --show-toplevel)\"; ${command}";
  }; # from any directory of the repo
  empty = what: expr: ''out=$(${expr}); echo "${what} = $out"; test "$out" = "[ ]"'';
  fleet = "path:$PWD?dir=templates/fleet";
in
{
  sven.kinds.site.sinks.commands.out =
    { commands, ... }:
    {
      devShells = lib.genAttrs systems (
        system:
        let
          pkgs = inputs.nixpkgs.legacyPackages.${system};
        in
        {
          default = inputs.devshell.legacyPackages.${system}.mkShell {
            name = "sven-docs";
            packages = [
              pkgs.nodejs
              pkgs.pnpm
              pkgs.jq
              pkgs.git
              pkgs.nixfmt-rfc-style # the same nixfmt as the fleet's flake-file
              pkgs.actionlint
              pkgs.shellcheck
              pkgs.gh
            ];
            commands = lib.concatLists commands; # each aspect gives a list
          };
        }
      );
    };

  sven.aspects.docs-commands = {
    at = sven.kinds.site;
    commands = [
      (cmd "docs" "docs-write" "write the pages and the sidebar from examples/"
        "cd docs && nix run .#write-files"
      )
      (cmd "flake" "each-flake" "run command in every flake.nix directory that has it" ''
        system=$(nix eval --impure --raw --expr builtins.currentSystem)
        git ls-files -z '*flake.nix' | xargs -0 -n1 dirname | sort | while read -r dir; do
          echo "== $dir"
          (cd "$dir" && bash -c "$@")
        done
      '')
      (cmd "docs" "docs-test" "the checks of every example (fast)"
        "cd docs && ${empty "failed" "nix eval --impure --file tests.nix failed"}"
      )
      (cmd "docs" "docs-e2e" "real NixOS, nix-darwin and home-manager evaluations of the examples"
        "cd docs && ${empty "e2e.failed" "nix eval --impure --file tests.nix e2e.failed"}"
      )
      (cmd "docs" "docs-check" "nix flake check of docs/: pages current, examples, e2e"
        "cd docs && nix flake check -L"
      )
      (cmd "docs" "docs-dev" "the site at localhost:4321, live"
        "cd docs && CI=true pnpm install --config.confirmModulesPurge=false && pnpm dev"
      )
      (cmd "docs" "docs-build" "build the site to docs/dist"
        "cd docs && CI=true pnpm install --frozen-lockfile --config.confirmModulesPurge=false && pnpm build"
      )
    ];
  };
  sven.aspects.fmt-commands = {
    at = sven.kinds.site;
    commands = [
      (cmd "fmt" "fmt-check" "every tracked nix file is formatted (nixfmt), as CI checks"
        "git ls-files -z '*.nix' | timeout 60 xargs -0 nixfmt --check"
      )
      (cmd "issue" "issue-eval"
        "issue-eval BODY DIR: an issue's nix blocks as one fleet, restricted; writes DIR/comment.md"
        "bash docs/issue/run.sh \"$@\""
      )
      (cmd "issue" "issue-comment"
        "issue-comment NUMBER FILE: post FILE on issue NUMBER, replacing sven's last comment (needs GH_TOKEN)"
        "gh issue comment \"$1\" --edit-last --body-file \"$2\" || gh issue comment \"$1\" --body-file \"$2\""
      )
      (cmd "fmt" "lint" "the workflows are valid (actionlint, with shellcheck)"
        "actionlint .github/workflows/*.yml"
      )
      (cmd "fmt" "fmt" "format every tracked nix file (nixfmt)"
        "git ls-files -z '*.nix' | xargs -0 nixfmt"
      )
    ];
  };
  sven.aspects.engine-commands = {
    at = sven.kinds.site;
    commands = [
      (cmd "engine" "engine-test" "the engine and library oracles" (
        empty "failed" "nix-instantiate --eval --strict tests -A failed"
      ))
      (cmd "engine" "engine-cost" "the memo cost oracles" "bash tests/cost.sh")
    ];
  };
  sven.aspects.fleet-commands = {
    at = sven.kinds.site;
    commands = [
      (cmd "fleet" "fleet-test" "the reference fleet's checks"
        "cd templates/fleet && ${empty "failed" "nix eval --impure --file tests.nix failed"}"
      )
      (cmd "fleet" "fleet-e2e" "the reference fleet's real evaluations"
        "cd templates/fleet && ${empty "e2e.failed" "nix eval --impure --file tests.nix e2e.failed"}"
      )
      (cmd "fleet" "fleet-cost" "the trimmed-module-list cost oracle"
        "cd templates/fleet && bash cost.sh"
      )
      (cmd "fleet" "fleet-mcp" "the MCP server tests" "bash templates/fleet/mcp/test.sh")
      (cmd "fleet" "fleet-check" "nix flake check of the fleet (VM tests are vmTests, not checks)"
        "nix flake check -L \"${fleet}\""
      )
      (cmd "fleet" "fleet-eval"
        "fleet-eval SYSTEM: every ci.json target of SYSTEM evaluates to a derivation"
        ''
          system=''${1:?usage: fleet-eval SYSTEM}
          jq -r --arg s "$system" '.[] | select(.system == $s) | .attr' templates/fleet/ci.json | while read -r attr; do
            drv=$(nix eval --raw "${fleet}#$attr.drvPath")
            echo "$attr $drv"
            case "$drv" in /nix/store/*.drv) ;; *) exit 1 ;; esac
          done
        ''
      )
      (cmd "fleet" "fleet-write" "regenerate the fleet's README.md and ci.json"
        "cd templates/fleet && nix run .#write-files"
      )
      (cmd "fleet" "fleet-flake" "regenerate the fleet's flake.nix"
        "cd templates/fleet && nix run .#write-flake"
      )
    ];
  };
  # every CI job of .github/workflows/test.yml, in order, stopping at the first failure
  sven.aspects.ci-command = {
    at = sven.kinds.site;
    commands = [
      (cmd "ci" "ci"
        "run the CI stages locally, in order: fmt, engine, docs, fleet (fleet-check and the per-arch evals not included)"
        "for c in fmt-check engine-test engine-cost docs-test docs-e2e docs-check docs-build fleet-test fleet-e2e fleet-cost fleet-mcp; do echo \"== $c\"; $c; done"
      )
    ];
  };
}
