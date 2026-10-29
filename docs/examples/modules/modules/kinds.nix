# NixOS `options` become kind fields. A field type is anything with `check`: here nixpkgs types and yen.lib.is.
{ yen, lib, ... }:
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
  };
  yen.kinds.host = {
    fields = {
      addr = lib.types.str;
      firewall.enable = yen.lib.opt lib.types.bool false; # mkEnableOption: a nested field with a default
      firewall.ports = yen.lib.opt (lib.types.listOf lib.types.port) [ ]; # checks the list, not its items
    };
    spawns.user = h: lib.filterAttrs (_: u: yen.lib.same u.on h) yen.user;
    sinks.nixos.reduce = yen.lib.reduce.merge;
  };
  # attrsOf (submodule { … }) in NixOS: here a kind, whose instances have names, refs and their own errors
  yen.kinds.user.fields = {
    on = yen.kinds.host;
    shell = yen.lib.opt lib.types.str "bash";
  };
}
