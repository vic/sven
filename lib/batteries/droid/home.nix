#: lib.batteries.droid.home :: { from; } -> key value -- the home-manager modules of sink from into nix-on-droid
# the home-manager modules of sink `from` into nix-on-droid's `home-manager.config`.
#   yen.kinds.phone.sinks.homeManager.droid = droid.home { from = yen.kinds.phone.sinks.homeManager; };
{ from }:
{ sinks, ... }:
{
  home-manager.config.imports = sinks.${from.__sink};
}
