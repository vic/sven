{ yen, lib, ... }:
{
  yen.kinds.host.fields.settings.k3s.role = yen.lib.opt lib.types.str "agent";
}
