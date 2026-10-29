# The fleet writes its own repo files. `files` collects github:sini/files modules; `write-files` writes them.
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
      inputs.reduce = sven.lib.reduce.merge; # flake inputs, declared by the aspects that use them
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
