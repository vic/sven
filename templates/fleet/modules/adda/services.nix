# adda: service aspects give their domains; the caddy host reads them as virtual hosts. The fleet also exports flake templates.
{ yen, lib, ... }:
{
  yen.kinds.host.sinks.service-domains = {
    of = lib.types.str;
    reduce = yen.lib.reduce.set;
  };
  yen.aspects.grafana = {
    at = yen.host.lb;
    service-domains = "grafana.example.org";
    nixos.services.grafana.enable = true;
  };
  yen.aspects.status-page = {
    at = yen.host.lb;
    service-domains = "status.example.org";
  };
  yen.aspects.caddy = {
    at = yen.host.lb;
    nixos =
      { service-domains, ... }:
      {
        services.caddy.enable = true;
        services.caddy.virtualHosts = lib.genAttrs service-domains (d: {
          extraConfig = "reverse_proxy localhost:3000";
        });
      };
  };
  yen.kinds.fleet.sinks.templates = {
    reduce = yen.lib.reduce.merge;
    out =
      { templates, ... }:
      {
        inherit templates;
      };
  };
  yen.aspects.fleet-template = {
    at = yen.fleet.main;
    templates.default = {
      path = ../..;
      description = "A yen fleet";
    };
  };
}
