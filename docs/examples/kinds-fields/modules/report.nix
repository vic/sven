# An aspect reads the fields of the nearest host.
{ yen, ... }:
{
  yen.aspects.report = {
    at = yen.kinds.host;
    report =
      { host, ... }:
      {
        ${host.name} = "${host.addr} (${toString host.cores} cores)";
      };
  };
}
