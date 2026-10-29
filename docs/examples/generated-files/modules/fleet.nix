# The fleet writes its own repo files. `flake-file` collects github:denful/flake-file options (flake.nix);
# `files` collects github:sini/files modules (README.md, CI workflow).
{
  sven,
  lib,
  inputs,
  ...
}:
let
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
in
{
  sven.kinds.fleet = {
    spawns.host = _: sven.host;
    sinks = {
      out.reduce = sven.lib.reduce.merge;
      flake-file = {
        reduce = sven.lib.reduce.merge; # flake inputs, declared by the aspects that use them
        out =
          { flake-file, ... }:
          let
            e = inputs.nixpkgs-unstable.lib.evalModules {
              # flake-file needs `valueMeta` on submodule options: nixos-25.05 lib lacks it
              specialArgs = { inherit inputs; };
              modules = [
                inputs.flake-file.flakeModules.flake
                { inherit flake-file; }
                { flake-file.formatter = p: p.nixfmt-rfc-style; }
              ];
            };
          in
          {
            packages.x86_64-linux.write-flake = e.config.flake-file.apps.write-flake pkgs;
            checks.x86_64-linux.flake-file = e.config.flake-file.check-flake-file pkgs;
          };
      };
      files.out =
        { files, ... }:
        let
          e = lib.evalModules {
            modules = [
              inputs.files.module
              {
                _module.args.pkgs = pkgs;
                files.root = inputs.self;
                files.relativeRoot = "docs/examples/generated-files";
              }
            ]
            ++ files;
          };
        in
        {
          packages.x86_64-linux.write-files = e.config.files.writer.drv;
          checks.x86_64-linux = e.config.files.checks; # each committed file must match
        };
    };
  };
  sven.kinds.host.sinks.nixos.out =
    { host, nixos, ... }:
    {
      nixosConfigurations.${host.name} = inputs.nixpkgs.lib.nixosSystem { modules = nixos; };
    };

  sven.fleet.main = { };
  sven.host.web = { };
  sven.flake = { out, ... }: out;
}
