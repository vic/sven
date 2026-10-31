# NixOS top-level `options` become module sinks. `yen.sinks` declares one: `of` checks each module's value,
# `reduce` merges the values. Any module reads the sink as an arg.
{ yen, ... }:
{
  yen.sinks.admins = {
    of = yen.lib.is builtins.isList;
    reduce = yen.lib.reduce.flat;
  };
  imports = [
    { admins = [ "ana" ]; }
    { admins = [ "bo" ]; }
    (
      { yen, admins, ... }:
      {
        yen.aspects.wheel = {
          at = yen.host.web;
          nixos.users.groups.wheel.members = admins;
        };
      }
    )
  ];
}
