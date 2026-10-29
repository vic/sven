{ yen, ... }:
{
  yen.environment.prod.domain = "example.com";
  yen.host.web.environment = yen.environment.prod;
  yen.host.db.environment = yen.environment.prod;
  yen.aspects.nginx = {
    at = yen.host.web;
    services = "nginx";
  };
}
