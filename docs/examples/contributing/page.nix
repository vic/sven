{
  title = "Contributing";
  description = "Issues with code, pull requests that exercise the docs examples, and every generator and test, in one place.";
  section = "project";
  order = 2;
  alsoAt = "../CONTRIBUTING.md"; # the same text is the repository's CONTRIBUTING.md: plain markdown only on this page

  body =
    {
      docs,
      inputs,
      dir,
      commands,
      lib,
      ...
    }:
    let
      reply = import (inputs.yen + "/docs/issue/eval.nix") {
        inherit (inputs) yen nixpkgs;
        blocks = dir + "/issue";
      };
      byCategory = lib.groupBy (c: c.category) commands;
    in
    [
      ''
        Thank you for helping. Bug reports, questions, docs fixes, examples and engine changes are all welcome.
        yen is small, and every page of its docs is a tested example, so a good report or a good example helps everyone after you.

        ## Open an issue: bring code

        An issue must have a yen module that shows the problem. The issue form asks for one. This is not a formality:
        CI evaluates every `nix` block of the issue as one fleet and comments the answer, often before a person reads it.

        Each block is one module of `modules/`. Declare the kinds it needs; `lib` is nixpkgs lib. For example:
      ''
      (docs.file "issue/block-1.nix")
      (docs.file "issue/block-2.nix")
      ''
        CI replies with the errors, the scopes, the active aspects and the invariant check:
      ''
      (docs.value reply)
      ''
        Here the answer is in the reply: a `one` sink with two elements is an error, not an override. The evaluation is pure and
        restricted (`--restrict-eval`): a block cannot read files outside its inputs, and it has a time limit.
        Run the same evaluation before you post, from the repository root, with your blocks in a directory as `block-1.nix`, `block-2.nix`:
      ''
      (docs.sh ''
        nix-instantiate --eval --strict --json --restrict-eval -I yen=. -I nixpkgs=channel:nixos-25.05 -I blocks=./my-issue \
          --expr 'import ./docs/issue/eval.nix { yen = <yen>; nixpkgs = <nixpkgs>; blocks = <blocks>; }'
      '')
      ''
        ## Send a pull request: exercise the examples

        The best pull request changes or adds an example under `docs/examples/`. An example is a page, a flake template and a test at once.

        1. For a bug, add a check to the `page.nix` of the closest example, or a `variants/` file that shows the bug. Run `docs-test`: it fails.
        2. Fix the engine (`default.nix`, `lib/`) or the example. Run `docs-test` again: it passes.
        3. For a feature, add a page: copy an example directory, edit `page.nix` and `modules/`, and give it `checks`.
        4. Run `docs-write` to regenerate the pages, then `ci` for every stage.

        A change to the engine also needs a test in `tests/default.nix`. Keep the engine to Nix builtins: no nixpkgs, no `throw`.

        ## Set up

        `nix develop ./docs` from the repository root (or `nix develop` in `docs/`) gives a devshell with every command below.
        `menu` lists them. Each command runs from the repository root, whatever your directory.
      ''
      (docs.table [ "Command" "Group" "What it does" ] (
        lib.concatMap (
          g:
          map (c: [
            "`${c.name}`"
            g
            c.help
          ]) byCategory.${g}
        ) (lib.attrNames byCategory)
      ))
      ''
        ## Generated files

        Do not edit generated files. Edit their source, then run the generator. A check fails when a committed file is stale.
      ''
      (docs.table
        [ "Files" "Source" "Generator" ]
        [
          [
            "`docs/src/content/docs/**`, `docs/src/sidebar.json`"
            "`docs/examples/*/page.nix`"
            "`docs-write`"
          ]
          [
            "`.github/workflows/test.yml`"
            "`docs/modules/ci.nix`"
            "`docs-write`"
          ]
          [
            "`.github/workflows/issue.yml`, `.github/ISSUE_TEMPLATE/*`"
            "`docs/modules/issues.nix`"
            "`docs-write`"
          ]
          [
            "`CONTRIBUTING.md`"
            "`docs/examples/contributing/page.nix`"
            "`docs-write`"
          ]
          [
            "`templates/fleet/README.md`, `templates/fleet/ci.json`"
            "`templates/fleet/modules/docs/`"
            "`fleet-write`"
          ]
          [
            "`templates/fleet/flake.nix`"
            "the `flake-file` sink of the fleet"
            "`fleet-flake`"
          ]
        ]
      )
      ''
        ## CI

        CI runs in stages, one after another, so a push does not start every job at once: `fmt`, `engine`, `docs`, `fleet`,
        then `flake-check` and one evaluation job per system. `ci` in the devshell runs the same stages locally, except the last.

        ## Maintenance

        - **Update inputs.** Run `nix flake update` in `docs/` and in `templates/fleet/`, then `ci`. nixpkgs comes from the
          nixos.org channel tarballs, not from GitHub.
        - **After a nixpkgs update**, the fleet's trimmed module lists belong to the old revision: `fleet-e2e` fails on
          `modlist-same-drv` until they are computed again.
        - **Format** with `fmt`; CI checks it with `fmt-check`.
        - **A new error code** in the engine fails the docs until the Error codes page (`docs/examples/errors-reference`) explains it.
      ''
    ];

  checks =
    {
      inputs,
      dir,
      eq,
      yes,
      no,
      ...
    }:
    let
      reply = import (inputs.yen + "/docs/issue/eval.nix") {
        inherit (inputs) yen nixpkgs;
        blocks = dir + "/issue";
      };
    in
    {
      reply = {
        t1 = eq (reply.modules) (2);
        t2 = eq (map (e: { inherit (e) code from; }) reply.errors) ([
          {
            code = "one";
            from = "fleet:main/host:web";
          }
        ]);
      };
    };
}
