#: lib.batteries.nixos.hostname :: { scope; } -> module -- networking.hostName is the scope name
# networking.hostName = the scope name
#   yen.aspects.hostname = { at = yen.kinds.host; nixos = nixos.hostname; };
{ scope, ... }:
{
  networking.hostName = scope.name;
}
