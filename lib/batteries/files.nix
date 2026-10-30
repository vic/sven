# Repo files with github:sini/files: the modules of a sink become `packages.<system>.write-files` and one check per file
# (the committed file must match). The value of the sink's `out` key.
#   yen.kinds.repo.sinks.files.out = yen.lib.batteries.files.writer {
#     from = yen.kinds.repo.sinks.files; inherit (inputs) files; inherit lib pkgs; root = inputs.self; };
let
  inherit ((import ./default.nix)) eval-modules;
in
{
  # one repo file from the texts of a sink, joined in its order: the value of a key that gives to the files sink.
  # With `reduce = yen.lib.batteries.ordered` on `from`, sections from any file go where their before and after say.
  #   files = files.document { from = yen.kinds.repo.sinks.readme; path = "README.md"; };
  document =
    {
      from,
      path,
      separator ? "\n",
    }:
    { sinks, ... }:
    {
      files.file.${path}.text = builtins.concatStringsSep separator sinks.${from.__sink};
    };

  writer =
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
    };
}
