# a public key file that is not in vars is an error record, never the text "absent"
{ yen, ... }:
{
  yen.assembly.lost = {
    kit = yen.kit.wireguard;
    roles.controller = {
      at = yen.machine.lb;
      settings.prefix = "10.9.0.0/24";
    };
  };
}
