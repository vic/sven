{ yen, ... }:
{
  yen.host.web.addr = "10.0.0.1";
  yen.host.db = {
    addr = "10.0.0.2";
    port = 2222;
    vpn = "vpn-database"; # an explicit value wins over `derive`
    labels.role = "database";
    settings.kernel.channel = "latest";
  };
}
