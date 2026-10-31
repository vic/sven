# the members of one assembly name different prefixes
{ yen, ... }:
{
  yen.assembly.split = {
    kit = yen.kit.wireguard;
    roles = {
      controller = {
        at = yen.machine.lb;
        settings.prefix = "10.9.0.0/24";
      };
      peer = {
        at = yen.machine.web;
        settings.prefix = "10.9.1.0/24";
      };
    };
  };
}
