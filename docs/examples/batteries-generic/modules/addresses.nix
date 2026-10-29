# claim: each address has one owner. Two hosts with one address is an error, and the fleet has no outputs.
{ yen, ... }:
{
  yen.kinds.fleet.sinks.addrs = {
    reduce = yen.lib.batteries.claim { key = addr: addr; };
    out =
      { sinks, ... }:
      {
        addrs = builtins.attrNames sinks.addrs;
      };
  };
  yen.aspects.addr = {
    at = yen.kinds.host;
    addrs = { host, ... }: host.addr;
  };
}
