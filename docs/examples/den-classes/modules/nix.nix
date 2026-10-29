# Den: a `nix` class, forwarded with den.batteries.forward into nix.settings of nixos and of homeManager.
# yen: a `nix` sink on each kind. Its other key gives the settings to the class of that kind.
{ yen, ... }:
let
  merge = yen.lib.reduce.merge;
in
{
  yen.kinds.host.sinks.nix = {
    reduce = merge;
    nixos =
      { nix, ... }:
      {
        nix.settings = nix;
      };
  };
  yen.kinds.home.sinks.nix = {
    reduce = merge;
    homeManager =
      { nix, ... }:
      {
        nix.settings = nix;
      };
  };

  # written once, for both
  yen.aspects.nix-settings = {
    at = [
      yen.kinds.host
      yen.kinds.home
    ];
    nix = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      warn-dirty = false;
    };
  };
  yen.aspects.builders = {
    at = yen.kinds.host;
    nix.max-jobs = 4;
  };
}
