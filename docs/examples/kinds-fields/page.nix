{
  title = "Kinds and fields";
  description = "A kind is a type of thing. Its fields are the data of each instance.";
  section = "model";
  order = 1;

  body =
    {
      docs,
      result,
      variant,
      ...
    }:
    [
      ''
        A kind is a type of thing: `host`, `user`, `environment`. yen has no built-in kinds. You declare each one.
        The `fields` of a kind are the data of each of its instances.
      ''
      (docs.file "modules/host.nix")
      ''
        An instance is `yen.<kind>.<name>`. The attribute name is the instance name. Any file can declare instances.
      ''
      (docs.file "modules/hosts.nix")
      ''
        An aspect reads the fields. Here, each host gives one line to a `report` sink on the fleet
        ([Sinks](/behavior/sinks/) explains how):
      ''
      (docs.file "modules/report.nix")
      (docs.value result.flake.report)
      ''
        ## Fields are strict

        A missing field, an unknown field and a value that fails its type are error records.
        Evaluation does not stop. The read gives `null`, and the `errors` query lists the problem.
        Add this file to the example:
      ''
      (docs.file "variants/typo.nix")
      ''
        `result.errors` now has three records. `near` names the field you probably meant:
      ''
      (docs.value (variant "variants/typo.nix").errors)
      (docs.tip "Ask the schema" ''
        `result.schema` describes every kind as data: fields with their type names, spawns and sinks.
        `result.data` gives every instance. Both print as JSON, for tools and agents.
      '')
      (docs.value result.schema.kinds.host.fields)
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
      report = eq (result.flake.report) ({
        db = "10.0.0.2 (16 cores)";
        web = "10.0.0.1 (4 cores)";
      });
      typo-codes = eq (map (e: e.code) (variant "variants/typo.nix").errors) ([
        "missing"
        "unknown-field"
        "check"
      ]);
    };
}
