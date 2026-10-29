# Typed elements (`of`): each replica gives one scrape job; lb reads the pool.
{ yen, ... }:
{
  yen.aspects.replica-scrape = {
    at = yen.kinds.replica;
    scrape =
      { replica, ... }:
      {
        job = replica.name;
        target = "${replica.db.zone}.${replica.region.zone}:9090";
      };
  };
  yen.aspects.monitoring = {
    at = yen.host.lb;
    nixos =
      { scrape, ... }:
      {
        services.prometheus.enable = true;
        services.prometheus.scrapeConfigs = map (j: {
          job_name = j.job;
          static_configs = [ { targets = [ j.target ]; } ];
        }) scrape;
      };
  };
}
