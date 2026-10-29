{ yen, ... }:
{
  yen.kinds.host.sinks.bridges.out =
    { host, bridges, ... }:
    {
      bridges.${host.name} = bridges;
    };
}
