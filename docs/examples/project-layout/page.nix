{
  title = "Project layout";
  description = "One module tree, two entry points: a flake, or plain Nix with default.nix.";
  section = "start";
  order = 3;

  body =
    { docs, ... }:
    [
      ''
        yen reads one module. A module is a path, a function or an attrset with three keys: `imports`, `_module.args`
        and `yen`. yen does not know what `inputs` or `lib` are. You give them as args, and they flow down the
        `imports` tree to every file below.
      ''
      docs.tree
      ''
        `modules/` is the fleet. Every file there is a module: put each kind, feature or host in its own file,
        and move files freely. File order never changes a result.

        ## Two entry points
      ''
      (docs.tabs [
        {
          label = "flake.nix";
          body = docs.file "flake.nix";
        }
        {
          label = "default.nix";
          body = docs.file "default.nix";
        }
      ])
      ''
        `mkFlake` gives the flake outputs. `eval` gives every query, `flake` included. Both read the same `modules/`.
      ''
      (docs.file "query.nix")
      (docs.sh ''
        nix eval --impure --file query.nix errors          # [ ] when the fleet is valid
        nix eval --impure --file query.nix graph.scopes    # every scope
        nix build -f query.nix flake.nixosConfigurations.laptop.config.system.build.toplevel
      '')
      ''
        ## NixOS without the nixpkgs flake

        `nixpkgs.lib.nixosSystem` exists only on the nixpkgs flake. `nixos/lib/eval-config.nix` works with a flake input
        and with a plain path, so one host file serves both entry points:
      ''
      (docs.fileWith "{7}" "modules/host.nix")
      (docs.caution "Args are explicit" ''
        yen gives a module only `yen` and the `_module.args` above it. A file that asks for `pkgs` at the top level gets an error record:
        `pkgs` belongs to NixOS. Ask for it inside a `nixos` element.
      '')
    ];

  checks =
    {
      inputs,
      dir,
      result,
      ...
    }:
    let
      q = import (dir + "/default.nix") { inherit (inputs) yen nixpkgs import-tree; };
    in
    {
      same-queries = q.errors == [ ] && q.graph == result.graph;
    };
  e2e =
    {
      inputs,
      dir,
      flake,
      ...
    }:
    let
      q = import (dir + "/default.nix") { inherit (inputs) yen nixpkgs import-tree; };
    in
    {
      same-system =
        q.flake.nixosConfigurations.laptop.config.system.build.toplevel.drvPath
        == flake.nixosConfigurations.laptop.config.system.build.toplevel.drvPath;
    };
}
