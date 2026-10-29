# Inside the fleet there is no `r`. An element reads results through its args and `yen.lib`.
{ yen, ... }:
{
  yen.aspects.inside = {
    at = yen.kinds.host;
    out =
      {
        scope,
        host,
        packages,
        ...
      }:
      {
        inside.${host.name} = {
          inherit packages; # a sink arg: the reduced value of `packages` at its receiver
          parent = scope.parent.id;
          users = map (u: u.name) (yen.lib.children yen.kinds.user scope);
          nginx = yen.lib.holds yen.aspects.nginx scope;
        };
      };
  };
}
