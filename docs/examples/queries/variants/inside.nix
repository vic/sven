# Inside the fleet there is no `result`. An element reads results through its args; a cycle asks the tree for the rest.
{ yen, ... }:
{
  yen.aspects.inside = {
    at = yen.kinds.host;
    cycle =
      {
        tree,
        scope,
        packages,
        ...
      }:
      let
        users.children = yen.kinds.user; # a tree request: the users under this host
      in
      {
        tree = [ users ];
        out = [
          {
            inside.${scope.name} = {
              packages = builtins.head packages; # a sink arg: the reduced value of `packages` at its receiver
              parent = scope.parent.id;
              users = map (u: u.name) (builtins.head (tree.select users));
              nginx = yen.lib.holds yen.aspects.nginx scope;
            };
          }
        ];
      };
  };
}
