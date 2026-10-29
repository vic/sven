{ yen, ... }:
{
  yen.aspects.ssh = {
    at = yen.kinds.host;
    ports = 22;
  };
  yen.aspects.runner = {
    at = yen.guest.ci;
    ports = 8080;
    config.runner.enable = true;
  };
}
