# a name where a ref goes: the kit, and a role's machines
{ yen, ... }:
{
  yen.assembly = {
    weekly = {
      kit = "borg";
      roles.server.at = yen.machine.nas;
    };
    hourly = {
      kit = yen.kit.borg;
      roles.server.at = "nas";
    };
  };
}
