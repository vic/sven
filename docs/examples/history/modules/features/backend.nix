{ yen, ... }:
{
  yen.aspects.backend = {
    at = yen.kinds.host;
    backends = { host, ... }: host.name;
  };
}
