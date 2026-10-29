# A type is anything with `check = value: bool`. yen adds defaults on top of it.
{ yen, lib, ... }:
let
  inherit (yen.lib)
    opt
    maybe
    derive
    is
    ;
in
{
  yen.kinds.host.fields = {
    addr = lib.types.str; # required
    port = opt lib.types.port 22; # a default
    jump = maybe lib.types.str; # null by default
    vpn = derive lib.types.str (self: "vpn-${self.name}"); # a default computed from the instance
    tags = opt (is (v: lib.isList v && lib.all lib.isString v)) [ ]; # your own check
    settings.kernel.channel = opt (lib.types.enum [
      "lts"
      "latest"
    ]) "lts"; # nested fields
  };
}
