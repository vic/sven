# networking.hostName = the scope name
#   yen.aspects.hostname = { at = yen.kinds.host; nixos = nixos.hostname; };
{ scope, ... }:
{
  networking.hostName = scope.name;
}
