# The pages and the sidebar are repo files, written by github:sini/files. Each file gets a check: the committed file must match.
{
  yen,
  lib,
  inputs,
  ...
}:
{
  yen.kinds.site.sinks.files.out = yen.lib.batteries.files.writer {
    from = yen.kinds.site.sinks.files;
    inherit (inputs) files;
    inherit lib;
    pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
    root = inputs.self;
    relativeRoot = "docs";
  };
}
