# fleet > environment > host > user. Groups are data: an environment grants groups, a user is in groups.
{
  yen,
  lib,
  inputs,
  ...
}:
let
  inherit (yen.lib)
    same
    maybe
    opt
    is
    ;
  listOf = t: is (v: lib.isList v && lib.all t.check v);
  meets = xs: ys: lib.any (x: lib.any (same x) ys) xs;
in
{
  yen.kinds.fleet = {
    spawns.environment = _: yen.environment;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.group = { };
  yen.kinds.environment = {
    fields = {
      domain = lib.types.str;
      base = maybe yen.kinds.environment; # settings it does not set come from here
      grants = opt (listOf yen.kinds.group) [ ];
      settings.timeZone = maybe lib.types.str;
    };
    spawns.host = s: lib.filterAttrs (_: h: same h.environment s) yen.host;
  };
  yen.kinds.host = {
    fields = {
      environment = yen.kinds.environment;
      settings.timeZone = maybe lib.types.str;
    };
    spawns.user = s: lib.filterAttrs (_: u: meets u.groups s.environment.grants) yen.user; # access from data
    sinks.nixos.out =
      { host, nixos, ... }:
      {
        nixosConfigurations.${host.name} = inputs.nixpkgs.lib.nixosSystem { modules = nixos; };
      };
  };
  yen.kinds.user.fields.groups = listOf yen.kinds.group;

  yen.fleet.main = { };
  yen.flake = { out, ... }: out;
}
