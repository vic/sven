{ yen, ... }:
{
  yen.kinds.host.fields.environment = yen.kinds.environment;
  yen.environment.prod.settings.zfs.arcMax = 8;

  yen.host.nas = {
    environment = yen.environment.prod;
    settings.zfs.arcMax = 32;
  };
  yen.host.node = {
    environment = yen.environment.prod;
    settings.k3s.role = "server";
  };
}
