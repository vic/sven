#: lib.kits.disko :: module -- kit disko and its data kind layout: a machine's disks from a named layout
# The kit `disko` owns the kind `layout` (data): `devices` makes disko devices from a device string. Its member gives
# them to sink `disks` of the machine kind, which the fleet declares (merge). The setting `layout` is a ref.
#   imports = [ inputs.yen.lib.kits.disko ];
{ yen, lib, ... }:
let
  layouts = import ./_layouts.nix { inherit lib; };
in
{
  yen.kinds.layout.fields.devices = yen.lib.is lib.isFunction;
  yen.layout = layouts;

  yen.kit.disko.roles.default.interface = {
    device.type = lib.types.str;
    layout.type = yen.kinds.layout // {
      description = "layout ref";
    }; # the kind checks; settings-typed names the type
  };
  yen.aspects.kit-disko = {
    at = yen.lib.all [
      yen.kinds.member
      (s: yen.lib.same (s.kit or null) yen.kit.disko)
    ];
    # a setting that is no layout is the error settings-typed gives; here it gives no disks ({ })
    disks =
      { member, ... }:
      let
        s = member.settings;
      in
      if s.layout ? devices then s.layout.devices s.device else { };
  };
}
