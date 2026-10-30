{
  title = "Sinks and reduce";
  description = "A sink collects elements and reduces them: list, set, one, merge, entries, or your own function.";
  section = "concepts";
  order = 8;

  body =
    {
      docs,
      result,
      variant,
      ...
    }:
    [
      ''
        A sink on a kind collects the elements that aspects give, and reduces them to one value.
        `of` checks each element.
      ''
      (docs.table
        [ "Reduce" "Value" "Error" ]
        [
          [
            "`list` (default)"
            "the elements in scope order"
            "none"
          ]
          [
            "`set`"
            "the elements without duplicates"
            "none"
          ]
          [
            "`one`"
            "the single element"
            "0 or 2+ elements"
          ]
          [
            "`merge`"
            "a deep attrset"
            "two different leaves at one path"
          ]
          [
            "`entries`"
            "`[ { from; value; } ]`: each value with the scope that gave it"
            "none"
          ]
          [
            "a function"
            "`[ { from; value; } ] -> { value; errors; }`"
            "the errors you give"
          ]
        ]
      )
      (docs.fileWith "{11-14}" "modules/sinks.nix")
      ''
        Two aspects give elements:
      ''
      (docs.file "modules/aspects.nix")
      ''
        And each sink reduces them:
      ''
      (docs.value result.flake.web)
      ''
        ## When a reduce fails

        A failed reduce is an error record. The other sinks still work:
      ''
      (docs.file "variants/conflicts.nix")
      (docs.value (variant "variants/conflicts.nix").errors)
      ''
        ## Your own reduce

        A reduce is any function from `[ { from; value; } ]` to `{ value; errors; }`. Write one when the merge order
        is the point: ranked layers, per-key strategies with provenance, or an export store where a scope can only write
        its own entries. The engine sets `from`. An element cannot say where it comes from, so a scope cannot write for another.
      ''
      (docs.tip "Errors and warnings as data" ''
        A sink such as `warnings` with `reduce = list` holds messages that do not fail the fleet.
        See [Errors as data](/concepts/errors/).
      '')
      (docs.caution "Names" ''
        Do not give a sink the name of a field or an arg. A sink `tags` and a field `tags` read as one arg.
      '')
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
      reduced = eq (result.flake.web) ({
        admin = "alice";
        groups = [
          "audio"
          "wheel"
        ];
        motd = [
          "welcome"
          "this host serves web"
        ];
        nginx.http = {
          gzip = true;
          servers.www.port = 80;
        };
        owners = [ "host" ];
        ports = [ 22 ];
      });
      failures = eq (map (e: e.code) (variant "variants/conflicts.nix").errors) ([
        "one"
        "merge"
        "of"
      ]);
    };
}
