#: lib.kits.wifi :: module -- wifi kit: one role with `networks`; every network gets a PSK secret file in the assembly's generator
# The generator is shared (all machines of the role get the same PSKs): one secret file `psk.<network>` per network.
# A `generators` element is one attrset, so a generator per network is not possible. The network list lands in
# /etc/wifi/networks; the PSK files are deployed by the vars plan.
#   imports = [ inputs.yen.lib.kits.wifi ];
{ yen, lib, ... }:
let
  inherit (yen.lib) all same;
  at = all [
    yen.kinds.member
    (s: same (s.kit or null) yen.kit.wifi)
  ];
in
{
  yen.kit.wifi.roles.default.interface.networks = {
    type = lib.types.attrs;
    default = { };
  };
  yen.aspects.kit-wifi = {
    inherit at;
    nixos =
      { member, ... }:
      {
        environment.etc."wifi/networks".text = toString (lib.attrNames member.settings.networks);
      };
  };
  yen.aspects.kit-wifi-psk = {
    inherit at;
    generators =
      { member, ... }:
      {
        name = "wifi.${member.assembly.name}";
        share = true;
        files = lib.genAttrs (map (n: "psk.${n}") (lib.attrNames member.settings.networks)) (_: {
          secret = true;
        });
      };
  };
}
