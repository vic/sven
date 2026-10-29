# `pkgs` is not a kind, a sink or `scope`: it stays open. The element is a module function.
{ yen, ... }:
{
  yen.aspects.open = {
    at = yen.host.lb;
    proxy =
      { host, pkgs, ... }:
      {
        name = host.name;
        shell = pkgs.bash;
      };
  };
}
