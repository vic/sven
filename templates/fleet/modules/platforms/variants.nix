# Den specialisations: a variant scope under a host; its nixos forwards into the host's specialisation.
{ yen, lib, ... }:
{
  yen.kinds.host.spawns.variant = s: lib.filterAttrs (_: v: yen.lib.same v.of s) yen.variant;
  yen.kinds.variant = {
    fields.of = yen.kinds.host;
    sinks.nixos.nixos =
      { variant, nixos, ... }:
      {
        specialisation.${variant.name}.configuration.imports = nixos;
      };
  };
  yen.variant.debug.of = yen.host.lb;
  yen.aspects.debug-kernel = {
    at = yen.kinds.variant;
    nixos.boot.kernelParams = [ "debug" ];
  };
}
