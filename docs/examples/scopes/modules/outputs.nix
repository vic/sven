# The flake gives the scope ids. An aspect asks the tree for the whole fleet (`graph = true`) to read them.
{ yen, ... }:
let
  whole.graph = true; # a tree request: the whole fleet
in
{
  yen.kinds.fleet.sinks.out.reduce = yen.lib.reduce.merge;
  yen.flake = { out, ... }: out;
  yen.aspects.tree = {
    at = yen.kinds.fleet;
    cycle =
      { tree, ... }:
      let
        yen = builtins.head (tree.select whole); # the whole fleet, with its data
      in
      {
        tree = [ whole ];
        out = [
          {
            scopes = map (s: s.id) yen.lib.graph.scopes;
          }
        ];
      };
  };
}
