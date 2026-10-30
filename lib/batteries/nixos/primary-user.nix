#: lib.batteries.nixos.primary-user :: { scope; } -> module -- the scope account administers the machine
# the scope's account administers the machine (Den's primary-user)
{ scope, ... }:
{
  users.users.${scope.name}.extraGroups = [
    "wheel"
    "networkmanager"
  ];
}
