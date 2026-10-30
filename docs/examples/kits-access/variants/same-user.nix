# the users kit twice for one user on one machine
{ yen, ... }:
{
  yen.assembly.ops-again = {
    kit = yen.kit.users;
    roles.default = {
      at = yen.machine.web;
      settings.user = "ops";
    };
  };
}
