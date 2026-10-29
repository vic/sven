# Flake level: sink -> sink chains, and elements that read one `out` path and write another.
{
  sven,
  lib,
  inputs,
  ...
}:
let
  pkgs = s: inputs.nixpkgs.legacyPackages.${s.name};
in
{
  sven.kinds.system.sinks = {
    devshell.out =
      { system, devshell, ... }:
      {
        devShells.${system.name}.default = (pkgs system).mkShell {
          packages = lib.concatMap (d: d.packages or [ ]) devshell;
          shellHook = lib.concatMapStrings (d: d.shellHook or "") devshell;
        };
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
  sven.aspects.dev-tools = {
    at = sven.kinds.system;
    devshell =
      { system, ... }:
      {
        packages = [ (pkgs system).nixfmt-rfc-style ];
      };
    treefmt = "nixfmt";
    git-hooks = "nixfmt --check";
  };
  sven.aspects.by-name = {
    at = sven.kinds.system;
    packages =
      { system, ... }:
      lib.filesystem.packagesFromDirectoryRecursive {
        inherit ((pkgs system)) callPackage;
        directory = ../../pkgs/by-name;
      };
  };
  sven.aspects.k8s-all = {
    at = sven.system.x86_64-linux;
    packages =
      { system, out, ... }:
      {
        k8s-all = (pkgs system).writeText "k8s-all.json" (builtins.toJSON out.k8sManifests);
      };
  };
  sven.aspects.local-overlay = {
    at = sven.kinds.fleet;
    out =
      { out, ... }:
      {
        overlays.default = final: _: out.packages.${final.stdenv.hostPlatform.system} or { };
      };
  };
}
