{ yen, ... }:
{
  yen.aspects.backend = {
    at = yen.lib.all [
      yen.kinds.host
      (s: s.name != "lb")
    ];
    backends = { host, ... }: host.addr; # a kind arg: the nearest host
  };
  yen.aspects.balancer = {
    at = yen.host.lb;
    # a sink arg: the reduced value at its nearest receiver (the environment);
    # `scope` is the scope itself; `cluster ? null` is optional, and this fleet has no cluster
    proxy =
      {
        environment,
        backends,
        scope,
        cluster ? null,
        ...
      }:
      {
        inherit backends;
        at = scope.id;
        env = environment.name;
        cluster = if cluster == null then "none" else cluster.name;
      };
  };
}
