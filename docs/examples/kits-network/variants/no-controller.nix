# a wireguard network with no controller
{ yen, ... }:
{
  yen.assembly.headless = {
    kit = yen.kit.wireguard;
    roles.controller = {
      at = _: false;
      settings.prefix = "10.9.0.0/24";
    };
  };
}
