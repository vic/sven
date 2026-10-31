# Services-like kits of the library (yen.lib.kits): each assembly names the machines of its roles; the kit does the rest.
# builders and a binary cache on lb for the web hosts, prometheus on lb scraping the web hosts, postgres on lb.
{ yen, inputs, ... }:
let
  inherit (yen) host kit;
  kits = inputs.yen.lib.kits;
in
{
  imports = [
    kits.remote-builders
    (kits.nix-cache { root = ../../vars/per-machine; })
    kits.monitoring
    kits.postgres
  ];

  yen.assembly = {
    builders = {
      kit = kit.remote-builders;
      roles = {
        builder = {
          at = host.lb;
          settings.speedFactor = 4;
        };
        client.at = [
          host.web-1
          host.web-2
        ];
      };
    };
    cache = {
      kit = kit.nix-cache;
      roles = {
        server = {
          at = host.lb;
        };
        client.at = [
          host.web-1
          host.web-2
        ];
      };
    };
    metrics = {
      kit = kit.monitoring;
      roles = {
        server.at = host.lb;
        exporter.at = [
          host.web-1
          host.web-2
        ];
      };
    };
    pg = {
      kit = kit.postgres;
      roles = {
        server.at = host.lb;
        client = {
          at = host.web-1;
          settings = {
            database = "shop";
            user = "shop";
          };
        };
      };
    };
  };
}
