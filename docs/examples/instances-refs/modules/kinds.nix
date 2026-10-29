# A kind is a type too: a field of kind `environment` holds a ref to an environment instance.
# Nothing spawns `environment`, so it is a data kind: its instances have no scope.
{ yen, lib, ... }:
{
  yen.kinds.environment.fields.domain = lib.types.str;
  yen.kinds.host.fields = {
    environment = yen.kinds.environment;
    backup = yen.lib.maybe yen.kinds.host; # a ref to another host, or null
  };
}
