# Two hosts. Each sink is one NixOS option: many files give to it, the engine reduces it.
{ yen, ... }:
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
    sinks.addrs.reduce = yen.lib.reduce.merge; # a fleet-level sink: every host gives, every host reads
  };
  yen.kinds.host = {
    fields.addr = yen.lib.is builtins.isString;
    fields.fqdn = yen.lib.derive (yen.lib.is builtins.isString) (i: "${i.name}.lan"); # a default from the instance
    sinks = {
      ports.reduce = yen.lib.reduce.set;
      firewall.reduce = yen.lib.reduce.one;
      settings.reduce = yen.lib.reduce.merge;
      motd.reduce = es: {
        # the lowest priority number wins, like mkForce over mkDefault
        value = (builtins.head (builtins.sort (a: c: a.value.prio < c.value.prio) es)).value.text;
        errors = [ ];
      };
      peers.reduce = yen.lib.reduce.one;
    };
  };
  yen.fleet.main = { };
  yen.flake =
    { addrs, ... }:
    {
      inherit addrs;
    }; # the flake outputs read a sink too
  yen.host = {
    a.addr = "10.0.0.1";
    b.addr = "10.0.0.2";
  };
}
