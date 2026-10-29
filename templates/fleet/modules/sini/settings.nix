# Per-feature settings: two files declare types at two paths of one field. Cascade with delegation.
{ yen, lib, ... }:
let
  inherit (yen.lib) maybe opt;
  setting = path: h: yen.lib.cascade path ([ h ] ++ h.environment.delegates ++ [ h.environment ]); # local > delegated > parent
in
{
  yen.kinds.machine.fields.settings.zfs.arcMax = maybe lib.types.int;
  yen.kinds.environment.fields.settings.zfs.arcMax = maybe lib.types.int;
  yen.kinds.environment.fields.delegates = opt (yen.helpers.listOf yen.kinds.environment) [ ];
  yen.environment.prod.settings.zfs.arcMax = 4294967296;
  yen.environment.staging.delegates = [ yen.environment.prod ];
  yen.host.web-1.settings.zfs.arcMax = 8589934592;
  yen.aspects.zfs = {
    at = yen.kinds.host;
    nixos =
      { host, ... }:
      let
        m = setting [ "settings" "zfs" "arcMax" ] host;
      in
      {
        boot.kernelParams = lib.optional (m != null) "zfs.zfs_arc_max=${toString m}";
      };
  };
}
