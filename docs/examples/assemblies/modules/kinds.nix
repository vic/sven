# An assembly is data: which machines take which role. Each machine spawns one `member` scope per role it has.
{ yen, lib, ... }:
let
  inherit (yen.lib) same is;
  membersOf =
    m:
    lib.listToAttrs (
      lib.concatMap (
        a:
        lib.concatMap (
          role:
          lib.optional (lib.any (same m) a.roles.${role}) (
            lib.nameValuePair "${a.name}.${role}" {
              assembly = a;
              inherit role;
            }
          )
        ) (lib.attrNames a.roles)
      ) (lib.attrValues yen.assembly)
    );
in
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
    sinks = {
      out.reduce = yen.lib.reduce.merge;
      exports.reduce = yen.lib.reduce.entries; # what members publish, with the scope that published it
    };
  };
  yen.kinds.assembly.fields.roles = is lib.isAttrs; # role name -> host refs
  yen.kinds.host = {
    fields.addr = lib.types.str;
    spawns.member = membersOf;
    sinks.config = {
      reduce = yen.lib.reduce.merge;
      out =
        { host, config, ... }:
        {
          config.${host.name} = config;
        };
    };
  };
  yen.kinds.member = { }; # its elements go up to its machine

  yen.fleet.main = { };
  yen.flake = { out, ... }: out;
}
