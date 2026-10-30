# Repo files with github:sini/files: the modules of a sink become `packages.<system>.write-files` and one check per file
# (the committed file must match). The value of the sink's `out` key.
#   yen.kinds.repo.sinks.files.out = yen.lib.batteries.files.writer {
#     from = yen.kinds.repo.sinks.files; inherit (inputs) files; inherit lib pkgs; root = inputs.self; };
let
  eval-modules = import ../eval-modules.nix;
in
{
  from,
  files,
  lib,
  pkgs,
  root,
  relativeRoot ? null,
}:
eval-modules {
  inherit from lib;
  modules = [
    files.module
    {
      _module.args.pkgs = pkgs;
      files = {
        inherit root;
      }
      // (if relativeRoot == null then { } else { inherit relativeRoot; });
    }
  ];
  result = e: {
    packages.${pkgs.stdenv.hostPlatform.system}.write-files = e.config.files.writer.drv;
    checks.${pkgs.stdenv.hostPlatform.system} = e.config.files.checks;
  };
}
