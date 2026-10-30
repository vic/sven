# a user's home-manager modules (sink `from`, at the user) into its machine: the value of the sink's key that gives
# to the machine's NixOS or nix-darwin sink.
#   yen.kinds.user.sinks.homeManager.nixos = home-manager.into-host { from = yen.kinds.user.sinks.homeManager; };
{ from }:
{ scope, sinks, ... }:
{
  home-manager.users.${scope.name}.imports = sinks.${from.__sink};
}
