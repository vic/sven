# One feature, many files: each file of modules/base/ adds to the same `base` aspect.
{ yen, ... }:
{
  yen.aspects.base = {
    at = yen.kinds.host; # den.default.includes: every host
    nixos.nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };
}
