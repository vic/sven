# A sink with no keys is a wall: a home's packages stop at the home and never reach the host.
{ yen, ... }:
{
  yen.kinds.host.sinks.packages.out =
    { host, packages, ... }:
    {
      packages.${host.name} = packages;
    };
  yen.kinds.home.sinks.packages = { };
  yen.aspects.editor = {
    at = [
      yen.kinds.user
      yen.kinds.home
    ];
    packages = { scope, ... }: "vim for ${scope.name}";
  };
}
