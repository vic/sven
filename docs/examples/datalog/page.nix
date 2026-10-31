{
  title = "Datalog";
  description = "Rules with negation over fleet data: well-founded models, stable models, proofs and why-not.";
  section = "query";
  order = 3;

  body =
    { docs, result, ... }:
    [
      ''
        Some questions are rules: "a host serves when it runs a web server and is not drained; a host is drained when a host
        it depends on is down." `yen.lib.datalog` solves ground rules with negation. Each rule is `{ head; pos; neg; }`.
        You ground the rules with Nix: one set per host. Each atom is a relation of `yen.relations` called by reference,
        and each term an instance: no relation or host is written as a string. In an answer, an instance is `{ kind; name; }`.
      ''
      (docs.file "modules/fleet.nix")
      (docs.fileWith "{17-29}" "modules/policy.nix")
      (docs.value result.flake.serving)
      (docs.table
        [ "Function" "Answer" ]
        [
          [
            "`wfs rules`"
            "the well-founded model: `{ true; false; undefined; }`. No strata needed."
          ]
          [
            "`stable rules`"
            "every stable model: one per consistent choice"
          ]
          [
            "`why rules model atom`"
            "the rules that prove an atom"
          ]
          [
            "`proof rules model atom`"
            "a proof tree; a positive cycle shows `cycle = true`"
          ]
          [
            "`whyNot rules model atom`"
            "per rule: the `missing` positive atoms and the `blocking` negative ones"
          ]
          [
            "`judge rules a notA`"
            "`supported`, `refuted`, `both`, `neither` or `unknown`"
          ]
          [
            "`facts atoms`"
            "atoms as rules with no body"
          ]
        ]
      )
      ''
        `web-2` does not serve: its database `db-2` is in maintenance, so `web-2` is drained. `whyNot` says so.
        The primary database is undefined in the well-founded model. The stable models list the two choices.
      ''
      (docs.note "Undefined is an answer" ''
        An atom the rules cannot decide is `undefined`, never a guess. When that matters, give an error record for it.
        [Invariants](/query/invariants/) use the same solver, and treat an undefined violation as `incomplete`, never a pass.
      '')
    ];

  checks =
    {
      result,
      eq,
      yes,
      no,
      ...
    }:
    let
      s = result.flake.serving;
      # an atom as the answer states it: the relation, then the instance identity
      atom = rel: name: [
        rel
        {
          kind = "host";
          inherit name;
        }
      ];
    in
    {
      serves = eq (s.serves) ([ "web-1" ]);
      choice = {
        t1 = eq (s.choices) ([
          [ "db-1" ]
          [ "db-2" ]
        ]);
        t2 = eq (s.undefined) ([
          (atom "primary" "db-1")
          (atom "primary" "db-2")
        ]);
      };
      blocking = eq ((builtins.head s.whyNot).blocking) ([ (atom "drained" "web-2") ]);
    };
}
