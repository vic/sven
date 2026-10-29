# Each aspect is one NixOS pattern. None of them knows the files that read it.
{ yen, ... }:
{
  yen.aspects = {
    fw = {
      at = yen.kinds.host;
      firewall = { ports, ... }: builtins.sort builtins.lessThan ports; # reads another option: config.ports
    };
    ssh = {
      at = yen.kinds.host;
      ports = 22;
    };
    web = {
      at = yen.host.a;
      ports = 80;
    };
    tls = {
      at = yen.aspects.web; # mkIf: active where web is
      ports = 443;
    };
    base = {
      at = yen.kinds.host;
      settings.log.level = "info";
      motd = {
        prio = 1000;
        text = "welcome";
      };
    };
    tuned = {
      at = yen.host.b;
      settings.log.file = "/var/log/b";
      motd = {
        prio = 50;
        text = "maintenance";
      };
    };
    addrs = {
      at = yen.kinds.host;
      addrs =
        { host, ... }:
        {
          ${host.name} = host.addr;
        };
      peers = { host, addrs, ... }: removeAttrs addrs [ host.name ]; # the other nodes, through the fleet
    };
  };
}
