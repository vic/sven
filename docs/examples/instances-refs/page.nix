{
  title = "Instances and refs";
  description = "A kind is a type: a field can hold a ref to another instance. Kinds that nothing spawns are data.";
  section = "concepts";
  order = 3;

  body =
    {
      docs,
      result,
      variant,
      ...
    }:
    [
      ''
        A kind is also a type. A field of type `yen.kinds.environment` holds a ref to an environment instance:
        `yen.environment.prod`, never the string `"prod"`.
      ''
      (docs.file "modules/kinds.nix")
      (docs.fileWith "{6-7}" "modules/instances.nix")
      ''
        Refs are lazy, so two hosts can point at each other. There is no cycle error.
        Follow a ref like an attrset, and compare two instances with `yen.lib.same`:
      ''
      (docs.file "modules/report.nix")
      (docs.value result.flake.report)
      ''
        ## Data kinds

        `environment` is a data kind: no kind spawns it. Its instances have no place in the scope tree,
        and refs to them still work. The tree has the fleet and the hosts only:
      ''
      (docs.scopes result)
      ''
        Groups, channels and secrets are good data kinds. [Scopes](/concepts/scopes/) shows how a kind gets a place in the tree.

        ## A string is not a ref

        A name where a ref goes is an error record, with the fix:
      ''
      (docs.file "variants/string-ref.nix")
      (docs.value (variant "variants/string-ref.nix").errors)
    ];

  checks =
    {
      result,
      variant,
      eq,
      yes,
      no,
      ...
    }:
    {
      report = eq (result.flake.report.web) ({
        backup = "db";
        fqdn = "web.example.com";
        peers = [ "db" ];
      });
      data-kind = eq (map (s: s.kind) result.graph.scopes) ([
        "fleet"
        "host"
        "host"
        "host"
      ]);
      ref-error = eq (map (e: e.code) (variant "variants/string-ref.nix").errors) ([ "ref" ]);
    };
}
