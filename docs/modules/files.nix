# The pages and the sidebar are repo files, written by github:sini/files. Each file gets a check: the committed file must match.
{ lib, inputs, ... }:
let
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
in
{
  yen.kinds.site.sinks.files.out =
    { files, ... }:
    let
      e = lib.evalModules {
        modules = [
          inputs.files.module
          {
            _module.args.pkgs = pkgs;
            files.root = inputs.self;
            files.relativeRoot = "docs";
          }
        ]
        ++ files;
      };
    in
    {
      packages.x86_64-linux.write-files = e.config.files.writer.drv;
      checks.x86_64-linux = e.config.files.checks;
    };
}
