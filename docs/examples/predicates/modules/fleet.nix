# Hosts with facts, guests (VMs) under hosts. An `active` output lists each aspect's scopes.
{ yen, lib, ... }:
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
  };
  yen.kinds.host = {
    fields = {
      cores = lib.types.int;
      gpu = yen.lib.opt lib.types.bool false;
    };
    spawns.guest = s: lib.filterAttrs (_: g: yen.lib.same g.on s) yen.guest;
  };
  yen.kinds.guest.fields.on = yen.kinds.host;

  yen.fleet.main = { };
  yen.host.big = {
    cores = 32;
    gpu = true;
  };
  yen.host.small.cores = 4;
  yen.guest.ci.on = yen.host.big;

}
