# The routing graph as a knowledge pack: sorted N-Triples with a sha256. Same fleet, same hash, any file order.
{ yen, ... }:
{
  yen.aspects.pack = {
    at = yen.kinds.fleet;
    out.rdfPack = removeAttrs (yen.lib.rdf.share {
      graph = yen.lib.graph;
      active = { };
      errors = [ ];
    }) [ "ntriples" ];
  };
}
