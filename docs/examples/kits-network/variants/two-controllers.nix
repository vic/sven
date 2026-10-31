# every machine a controller: wireguard and zerotier allow one
{ yen, ... }:
{
  yen.assembly.twin = {
    kit = yen.kit.zerotier;
    roles.controller.at = yen.kinds.machine;
  };
}
