# Flake level: sink -> sink chains, and elements that read one `out` path and write another.
{
  yen,
  lib,
  inputs,
  ...
}:
let
  pkgs = s: inputs.nixpkgs.legacyPackages.${s.name};
in
{
  yen.kinds.system.sinks = {
    devshell.out = yen.lib.batteries.devshell.mkshell {
      from = yen.kinds.system.sinks.devshell;
      pkgsOf = pkgs;
    };
    treefmt.out =
      { system, treefmt, ... }:
      {
        formatter.${system.name} = (pkgs system).writeShellScriptBin "fmt" (lib.concatLines treefmt);
      };
    git-hooks = {
      out =
        { system, git-hooks, ... }:
        {
          checks.${system.name}.pre-commit =
            (pkgs system).runCommand "pre-commit" { }
              "echo '${lib.concatLines git-hooks}' > $out";
        };
      devshell =
        { git-hooks, ... }:
        {
          shellHook = "echo hooks: ${toString git-hooks}\n";
        }; # a sink feeding another sink
    };
  };
  yen.aspects.dev-tools = {
    at = yen.kinds.system;
    devshell =
      { system, ... }:
      {
        packages = [ (pkgs system).nixfmt-rfc-style ];
      };
    treefmt = "nixfmt";
    git-hooks = "nixfmt --check";
  };
  yen.aspects.by-name = {
    at = yen.kinds.system;
    packages =
      { system, ... }:
      lib.filesystem.packagesFromDirectoryRecursive {
        inherit ((pkgs system)) callPackage;
        directory = ../../pkgs/by-name;
      };
  };
  yen.aspects.k8s-all = {
    at = yen.system.x86_64-linux;
    packages =
      { system, out, ... }:
      {
        k8s-all = (pkgs system).writeText "k8s-all.json" (builtins.toJSON out.k8sManifests);
      };
  };
  yen.aspects.local-overlay = {
    at = yen.kinds.fleet;
    out =
      { out, ... }:
      {
        overlays.default = final: _: out.packages.${final.stdenv.hostPlatform.system} or { };
      };
  };
}
