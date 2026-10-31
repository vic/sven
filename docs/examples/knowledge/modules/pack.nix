# The routing graph as a knowledge pack: sorted N-Triples with a sha256. Same fleet, same hash, any file order.
{ yen, ... }:
let
  whole.graph = true; # a tree request: the whole fleet
in
{
  yen.aspects.pack = {
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
            rdfPack = removeAttrs (yen.lib.rdf.share {
              graph = yen.lib.graph;
              active = { };
              errors = [ ];
            }) [ "ntriples" ];
          }
        ];
      };
  };
}
