# Tags: a set per host; nixos.colmena adds the environment and the active role aspects. A host profile does not reach the host's guests (#67).
{ yen, lib, ... }:
{
  yen.kinds.host.sinks.tags = {
    of = lib.types.str;
    reduce = yen.lib.reduce.set;
  };
  yen.aspects.role-server.at = [
    yen.host.lb
    yen.host.web-1
    yen.host.web-2
  ];
  yen.aspects.role-workstation.at = yen.host.stage;
  yen.aspects.role-laptop.at = yen.host.stage;
  yen.aspects.thermald = {
    at = yen.aspects.role-laptop;
    nixos.services.thermald.enable = true;
  };
  yen.aspects.profile-workstation.at = yen.host.stage;
  yen.aspects.desktop.at = [ yen.aspects.profile-workstation ]; # `at` from two files is a union; ci, stage's guest, gets nothing
}
