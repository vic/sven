# `cascade path xs`: the first non-null value along a list, in your order.
{ yen, ... }:
{
  yen.aspects.report = {
    at = yen.kinds.host;
    report =
      { host, ... }:
      {
        ${host.name} = {
          arcMax = yen.lib.cascade [ "settings" "zfs" "arcMax" ] [ host host.environment ];
          k3s = host.settings.k3s.role;
        };
      };
  };
}
