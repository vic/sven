# base's second file: every machine's A record. dns reads the pool at the edge environment.
{ yen, ... }:
{
  yen.aspects.base.records =
    { scope, ... }:
    {
      ${scope.name} = scope.addr;
    };
  yen.aspects.dns = {
    at = yen.environment.prod;
    terraform =
      { records, lib, ... }:
      {
        resource.cloudflare_record = lib.mapAttrs (_: value: {
          inherit value;
          type = "A";
        }) records;
      };
  };
}
