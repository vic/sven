# An element reads a field of another instance: refused, with the fix.
{ yen, ... }:
{
  yen.kinds.host.fields.addr = yen.lib.is builtins.isString;
  yen.host.server.addr = "10.0.0.1";
  yen.aspects.read-addr = {
    at = yen.kinds.host;
    cycle =
      { ... }:
      {
        out = [ { addr.server = yen.host.server.addr; } ];
      };
  };
}
