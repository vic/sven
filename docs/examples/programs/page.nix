{
  title = "Change programs";
  description = "A change as a list of data ops: set, ref, place, new. An agent writes a program, not Nix code.";
  section = "agents";
  order = 3;

  body =
    {
      docs,
      inputs,
      dir,
      ...
    }:
    let
      P =
        p:
        import (dir + "/dry-run.nix") {
          program = p;
          sven = inputs.sven.outPath;
          inherit (inputs) nixpkgs import-tree;
        };
    in
    [
      ''
        Writing Nix is a poor interface for an agent: it can write anything, and a typo is a parse error.
        `sven.lib.program` writes a change as data. Four ops cover a fleet change:
      ''
      (docs.table
        [ "Op" "Effect" ]
        [
          [
            "`{ op = \"set\"; path; value; }`"
            "one declaration path gets a value"
          ]
          [
            "`{ op = \"ref\"; path; kind; name; }`"
            "one declaration path gets an instance ref"
          ]
          [
            "`{ op = \"place\"; aspect; kind; name; }`"
            "the aspect is also active at that instance"
          ]
          [
            "`{ op = \"new\"; kind; name; fields; }`"
            "a new instance; a field `{ ref = { kind; name; }; }` is a ref"
          ]
        ]
      )
      (docs.file "programs/new-cache.json")
      (docs.file "dry-run.nix")
      (docs.value (P "programs/new-cache.json"))
      ''
        ## Checked against the schema

        `validate r prog` checks each op before anything runs: kinds, fields and aspects must exist, with `near` for typos.
        `dryRun` validates first, and stages only a valid program:
      ''
      (docs.file "programs/typos.json")
      (docs.value (P "programs/typos.json"))
      (docs.table
        [ "Function" "Use" ]
        [
          [
            "`validate r prog`"
            "error records, `[ ]` when the program is valid"
          ]
          [
            "`toModule prog`"
            "the program as a sven module, to import"
          ]
          [
            "`dryRun { base; prog; grant; rejected; }`"
            "validate, then [stage](/agents/stage/)"
          ]
          [
            "`render prog`"
            "JSON, to store or send"
          ]
        ]
      )
    ];

  checks =
    { inputs, dir, ... }:
    let
      P =
        p:
        import (dir + "/dry-run.nix") {
          program = p;
          sven = inputs.sven.outPath;
          inherit (inputs) nixpkgs import-tree;
        };
    in
    {
      ok = (P "programs/new-cache.json").ok;
      typos =
        map (e: e.near) (P "programs/typos.json").errors == [
          [ "addr" ]
          [ "postgres" ]
        ];
    };
}
