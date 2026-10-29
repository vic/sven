# A sink's other keys give elements to other sinks. They run at the receiver, with its args.
{ yen, ... }:
let
  inherit (yen.lib.reduce) merge;
in
{
  yen.kinds.host.sinks = {
    ports.config =
      { ports, ... }:
      {
        firewall.allowedTCPPorts = ports;
      }; # ports feed config
    config = {
      reduce = merge;
      out =
        { host, config, ... }:
        {
          config.${host.name} = config;
        };
    };
  };
  yen.kinds.guest.sinks = {
    ports.config =
      { ports, ... }:
      {
        firewall.allowedTCPPorts = ports;
      };
    config = {
      reduce = merge;
      config =
        { guest, config, ... }:
        {
          vms.${guest.name} = config;
        }; # its own name: a forward up, to the host
    };
  };
}
