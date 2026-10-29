# Contributing

<!-- Generated from docs/examples/contributing/page.nix. Edit there, then run `nix run .#write-files` in docs/. -->

Thank you for helping. Bug reports, questions, docs fixes, examples and engine changes are all welcome.
sven is small, and every page of its docs is a tested example, so a good report or a good example helps everyone after you.

## Open an issue: bring code

An issue must have a sven module that shows the problem. The issue form asks for one. This is not a formality:
CI evaluates every `nix` block of the issue as one fleet and comments the answer, often before a person reads it.

Each block is one module of `modules/`. Declare the kinds it needs; `lib` is nixpkgs lib. For example:


```nix title="issue/block-1.nix"
# The fleet: a root kind, and a host kind with an `admin` sink that takes one element.
{ sven, ... }:
{
  sven.kinds.fleet.spawns.host = _: sven.host;
  sven.kinds.host.sinks.admin.reduce = sven.lib.reduce.one;
  sven.fleet.main = { };
  sven.host.web = { };
}
```

```nix title="issue/block-2.nix"
# The problem: two aspects give an admin. I expected the second to win.
{ sven, ... }:
{
  sven.aspects.ops = {
    at = sven.kinds.host;
    admin = "ana";
  };
  sven.aspects.dev = {
    at = sven.host.web;
    admin = "bo";
  };
}
```

CI replies with the errors, the scopes, the active aspects and the invariant check:


```nix title="result"
{
  active = {
    dev = [
      "fleet:main/host:web"
    ];
    ops = [
      "fleet:main/host:web"
    ];
  };
  check = {
    incomplete = [ ];
    ok = true;
    violations = [ ];
  };
  errors = [
    {
      class = "fixable";
      code = "one";
      error = "one: got 2 elements";
      from = "fleet:main/host:web";
      got = 2;
      path = [ ];
      sink = "admin";
      want = 1;
    }
  ];
  modules = 2;
  scopes = [
    "fleet:main"
    "fleet:main/host:web"
  ];
  undefined = [ ];
}
```

Here the answer is in the reply: a `one` sink with two elements is an error, not an override. The evaluation is pure and
restricted (`--restrict-eval`): a block cannot read files outside its inputs, and it has a time limit.
Run the same evaluation before you post, from the repository root, with your blocks in a directory as `block-1.nix`, `block-2.nix`:


```sh frame="terminal"
nix-instantiate --eval --strict --json --restrict-eval -I sven=. -I nixpkgs=channel:nixos-25.05 -I blocks=./my-issue \
  --expr 'import ./docs/issue/eval.nix { sven = <sven>; nixpkgs = <nixpkgs>; blocks = <blocks>; }'
```

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


| Command | Group | What it does |
|---|---|---|
| `ci` | ci | run the CI stages locally, in order: fmt, engine, docs, fleet (fleet-check and the per-arch evals not included) |
| `docs-write` | docs | write the pages and the sidebar from examples/ |
| `docs-test` | docs | the checks of every example (fast) |
| `docs-e2e` | docs | real NixOS, nix-darwin and home-manager evaluations of the examples |
| `docs-check` | docs | nix flake check of docs/: pages current, examples, e2e |
| `docs-dev` | docs | the site at localhost:4321, live |
| `docs-build` | docs | build the site to docs/dist |
| `engine-test` | engine | the engine and library oracles |
| `engine-cost` | engine | the memo cost oracles |
| `each-flake` | flake | run command in every flake.nix directory that has it |
| `fleet-test` | fleet | the reference fleet's checks |
| `fleet-e2e` | fleet | the reference fleet's real evaluations |
| `fleet-cost` | fleet | the trimmed-module-list cost oracle |
| `fleet-mcp` | fleet | the MCP server tests |
| `fleet-check` | fleet | nix flake check of the fleet (VM tests are vmTests, not checks) |
| `fleet-eval` | fleet | fleet-eval SYSTEM: every ci.json target of SYSTEM evaluates to a derivation |
| `fleet-write` | fleet | regenerate the fleet's README.md and ci.json |
| `fleet-flake` | fleet | regenerate the fleet's flake.nix |
| `fmt-check` | fmt | every tracked nix file is formatted (nixfmt), as CI checks |
| `lint` | fmt | the workflows are valid (actionlint, with shellcheck) |
| `fmt` | fmt | format every tracked nix file (nixfmt) |
| `issue-eval` | issue | issue-eval BODY DIR: an issue's nix blocks as one fleet, restricted; writes DIR/comment.md |
| `issue-comment` | issue | issue-comment NUMBER FILE: post FILE on issue NUMBER, replacing sven's last comment (needs GH_TOKEN) |

## Generated files

Do not edit generated files. Edit their source, then run the generator. A check fails when a committed file is stale.


| Files | Source | Generator |
|---|---|---|
| `docs/src/content/docs/**`, `docs/src/sidebar.json` | `docs/examples/*/page.nix` | `docs-write` |
| `.github/workflows/test.yml` | `docs/modules/ci.nix` | `docs-write` |
| `.github/workflows/issue.yml`, `.github/ISSUE_TEMPLATE/*` | `docs/modules/issues.nix` | `docs-write` |
| `CONTRIBUTING.md` | `docs/examples/contributing/page.nix` | `docs-write` |
| `templates/fleet/README.md`, `templates/fleet/ci.json` | `templates/fleet/modules/docs/` | `fleet-write` |
| `templates/fleet/flake.nix` | the `flake-file` sink of the fleet | `fleet-flake` |

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

