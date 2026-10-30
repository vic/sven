# yen docs

The yen documentation site. Astro and Starlight render it. A yen fleet writes it.

Every page is generated. Do not edit `src/content/docs/` or `src/sidebar.json`.

## Layout

- `examples/<slug>/`: one page each. `page.nix` has the prose. `flake.nix` and `modules/` are a flake template:
  every code block on the page is one of its files.
- `modules/`: the docs site as a yen fleet. Each page is an instance of the `page` kind.
  Its aspect gives the `.mdx` file, the sidebar entry, the template and the tests.
- `tests.nix`: the oracles of every example.
- `modules/ci.nix`: yen's CI, `.github/workflows/test.yml`, also written by `nix run .#write-files`.
  Stages run one after another: fmt, engine, docs, fleet, then `flake-check` and one eval job per system.

## Commands

`nix develop ./docs` from the repository root (or `nix develop` here) gives a devshell. Its commands run from the root,
whatever the directory. `menu` lists them: `docs-write`, `docs-test`, `docs-e2e`, `docs-check`,
`docs-dev`, `docs-build`, the engine and fleet tests and generators, and `ci` (every CI job, in order).
The commands are a sink of the docs fleet: see `modules/devshell.nix`.

Without the devshell:

```sh
nix run github:denful/fastest#fastest -- --flake ".?dir=docs#tests" fast   # every example check (yen queries)
nix run github:denful/fastest#fastest -- --flake ".?dir=docs#tests" e2e    # real NixOS, nix-darwin and home-manager evaluations
nix run .#write-files                           # write src/content/docs and src/sidebar.json
nix flake check                                 # pages current
pnpm install && pnpm dev                        # the site at localhost:4321
```

A new page is a new directory under `examples/`. Copy one, change `page.nix`, then run `nix run .#write-files`.
New files are visible to Nix only when the VCS tracks them.

Each template is published as a flake template:

```sh
nix flake init -t github:vic/yen#getting-started
```
