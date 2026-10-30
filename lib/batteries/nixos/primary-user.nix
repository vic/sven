# the scope's account administers the machine (Den's primary-user)
{ scope, ... }:
{
  users.users.${scope.name}.extraGroups = [
    "wheel"
    "networkmanager"
  ];
}
