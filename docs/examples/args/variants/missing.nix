# `cluster` without a default: no answer at lb, so the element is not given.
{ yen, ... }:
{
  yen.aspects.cluster-name = {
    at = yen.host.lb;
    proxy = { cluster, ... }: cluster.name;
  };
}
