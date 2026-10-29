# A set collector with a per-host filter (sini cortex-cuda `unpersist`).
{
  yen,
  lib,
  inputs,
  ...
}:
{
  yen.kinds.machine.fields.unpersist = yen.lib.opt (yen.helpers.listOf lib.types.str) [ ];
  yen.host.web-2.unpersist = [ "/var/lib/nginx" ];
  yen.kinds.host.sinks.persist = {
    of = lib.types.str;
    reduce = yen.lib.reduce.set;
    nixos =
      { scope, persist, ... }:
      {
        imports = [ inputs.impermanence.nixosModules.impermanence ];
        environment.persistence."/persist".directories = lib.subtractLists scope.unpersist persist;
      };
  };
}
