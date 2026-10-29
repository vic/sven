# Written by an agent.
{ yen, ... }:
{
  yen.aspects.metrics = {
    at = yen.kinds.host;
    services = "prometheus-node-exporter";
  };
}
