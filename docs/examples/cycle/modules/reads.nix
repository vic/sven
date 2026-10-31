# A host asks the tree for every host, and counts the other ones.
{ yen, ... }:
{
  yen.aspects.peers = {
    at = yen.kinds.host;
    cycle =
      { tree, scope, ... }:
      let
        hosts.instances = yen.kinds.host;
      in
      {
        tree = [ hosts ];
        out = [
          {
            peers.${scope.name} = builtins.length (
              builtins.filter (h: h.name != scope.name) (builtins.head (tree.select hosts))
            );
          }
        ];
      };
  };
}
