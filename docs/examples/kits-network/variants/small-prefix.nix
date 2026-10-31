# a prefix that is no IPv4 /16 to /24
{ yen, ... }:
{
  yen.assembly.tiny = {
    kit = yen.kit.wireguard;
    roles.controller = {
      at = yen.machine.lb;
      settings.prefix = "10.8.0.0/30";
    };
  };
}
