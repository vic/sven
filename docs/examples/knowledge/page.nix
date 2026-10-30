{
  title = "Knowledge packs";
  description = "The fleet as sorted N-Triples with a sha256, and SHACL shapes from the schema, for graph stores.";
  section = "agents";
  order = 4;

  body =
    {
      docs,
      result,
      engine,
      ...
    }:
    let
      pack = engine.rdf.share result;
    in
    [
      ''
        An agent with a knowledge store (a triple store such as quipu) can keep the fleet as a graph and query it with SPARQL.
        `yen.lib.rdf.share result` gives the eval result as sorted N-Triples: scopes, kinds, parents, active aspects, every routed
        element as a node with its origin, and errors. It adds a sha256 and a count.
      ''
      (docs.file "modules/hosts.nix")
      (docs.code "text" (
        builtins.concatStringsSep "\n" (
          builtins.genList (
            i: builtins.elemAt (builtins.filter builtins.isString (builtins.split "\n" pack.ntriples)) i
          ) 12
        )
        + "\n…"
      ))
      (docs.value { inherit (pack) count sha256; })
      ''
        ## Same fleet, same hash

        The triples are sorted, and yen gives the same answer whatever the file order. So two revisions compare by hash first.
        The docs check it: the files of this template, loaded in reverse order, give the same sha256.

        A fleet can give its pack as a flake output:
      ''
      (docs.file "modules/pack.nix")
      ''
        ## Shapes

        `yen.lib.rdf.shacl result` gives SHACL shapes from the schema: one node shape per kind with scopes, `yen:name` required,
        `yen:parent` of the spawning kind, each field at most once, and `sh:class` for ref fields.
      ''
      (docs.code "turtle" (builtins.substring 0 640 (engine.rdf.shacl result) + "…"))
      (docs.tip "One snapshot per revision" ''
        Store each revision's pack under one snapshot key, replacing the last. The store keeps old ones readable by transaction,
        so "what did the fleet look like before this change" is a query.
      '')
    ];

  checks =
    {
      result,
      engine,
      only,
      eq,
      yes,
      no,
      ...
    }:
    {
      stable = eq ((engine.rdf.share result).sha256) (
        (engine.rdf.share (only [
          "modules/pack.nix"
          "modules/hosts.nix"
          "modules/fleet.nix"
        ])).sha256
      );
      shapes = yes (builtins.isString (engine.rdf.shacl result));
    };
}
