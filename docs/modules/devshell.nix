# `nix develop` in docs/: a numtide/devshell. Its commands are a sink: each aspect gives the commands of its part.
# Every command runs from the repo root, whatever the directory: `nix develop ./docs` from the root, or `nix develop` in docs/.
# CI runs these commands and nothing else (modules/ci.nix), so every CI step runs the same way locally.
{
  yen,
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
  # every suite runs on github:denful/fastest: tests.<suite>.<test> = { expr; expected; }, in parallel
  fastest = dir: suite: ''fastest -q --flake "$PWD${dir}#tests" ${suite}'';
  fleet = "path:$PWD?dir=templates/fleet";
in
{
  yen.kinds.site.sinks.commands.out = yen.lib.batteries.devshell.numtide {
    from = yen.kinds.site.sinks.commands; # each aspect gives a list
    inherit (inputs) devshell;
    inherit systems;
    pkgsOf = system: inputs.nixpkgs.legacyPackages.${system};
    name = "yen-docs";
    packages = pkgs: [
      pkgs.nodejs_24 # Astro 7 needs Node >= 22.23.4; nodejs here is 22.20
      (pkgs.pnpm.override { nodejs = pkgs.nodejs_24; })
      pkgs.jq
      pkgs.git
      pkgs.nixfmt-rfc-style # the same nixfmt as the fleet's flake-file
      pkgs.actionlint
      pkgs.shellcheck
      pkgs.gh
      inputs.fastest.packages.${pkgs.stdenv.hostPlatform.system}.fastest # tests run here, no flake fetch per run
    ];
  };

  yen.aspects.docs-commands = {
    at = yen.kinds.site;
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
      (cmd "docs" "docs-test" "the checks of every example (fast)" (fastest "?dir=docs" "fast"))
      (cmd "docs" "docs-e2e" "real NixOS, nix-darwin and home-manager evaluations of the examples" (
        fastest "?dir=docs" "e2e"
      ))
      (cmd "docs" "docs-check" "nix flake check of docs/: pages and workflows current"
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
  yen.aspects.fmt-commands = {
    at = yen.kinds.site;
    commands = [
      (cmd "fmt" "fmt-check" "every tracked nix file is formatted (nixfmt), as CI checks"
        "git ls-files -z '*.nix' | timeout 60 xargs -0 nixfmt --check"
      )
      (cmd "issue" "issue-eval"
        "issue-eval BODY DIR: an issue's nix blocks as one fleet, restricted; writes DIR/comment.md"
        "bash docs/issue/run.sh \"$@\""
      )
      (cmd "issue" "issue-comment"
        "issue-comment NUMBER FILE: post FILE on issue NUMBER, replacing yen's last comment (needs GH_TOKEN)"
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
  yen.aspects.engine-commands = {
    at = yen.kinds.site;
    commands = [
      (cmd "engine" "engine-test" "the engine and library suites" (fastest "" ""))
      (cmd "engine" "engine-cost" "the memo cost oracles" "bash tests/cost.sh")
    ];
  };
  yen.aspects.fleet-commands = {
    at = yen.kinds.site;
    commands = [
      (cmd "fleet" "fleet-test" "the reference fleet's checks" (fastest "?dir=templates/fleet" "fleet"))
      (cmd "fleet" "fleet-e2e" "the reference fleet's real evaluations" (
        fastest "?dir=templates/fleet" "e2e"
      ))
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
  yen.aspects.ci-command = {
    at = yen.kinds.site;
    commands = [
      (cmd "ci" "ci"
        "run the CI stages locally, in order: fmt, engine, docs, fleet (fleet-check and the per-arch evals not included)"
        "for c in fmt-check engine-test engine-cost docs-test docs-e2e docs-check docs-build fleet-test fleet-e2e fleet-cost fleet-mcp; do echo \"== $c\"; $c; done"
      )
      (cmd "ci" "test-all" "every *-test command: engine, docs, fleet (no e2e, no cost)"
        "for c in engine-test docs-test fleet-test; do echo \"== $c\"; $c; done"
      )
      (cmd "ci" "fastest-tests"
        "every fastest suite at once, in parallel: engine, docs fast and e2e, fleet and e2e (FASTEST_WORKERS each, default 4)"
        ''
          export FASTEST_WORKERS=''${FASTEST_WORKERS:-4}
          pids=()
          for t in "|" "?dir=docs|fast" "?dir=docs|e2e" "?dir=templates/fleet|fleet" "?dir=templates/fleet|e2e"; do
            ${fastest "\${t%%|*}" "\${t#*|}"} & pids+=("$!")
          done
          rc=0
          for p in "''${pids[@]}"; do wait "$p" || rc=1; done
          exit "$rc"
        ''
      )
      (cmd "ci" "check-all" "every *-check command: fmt, docs, fleet"
        "for c in fmt-check docs-check fleet-check; do echo \"== $c\"; $c; done"
      )
    ];
  };
}
