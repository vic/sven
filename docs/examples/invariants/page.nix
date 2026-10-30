{
  title = "Invariants";
  description = "Rules that must hold across the whole fleet, checked before deploy: `result.check`.";
  section = "query";
  order = 5;

  body =
    {
      docs,
      result,
      variant,
      ...
    }:
    [
      ''
        An invariant is a rule about the whole fleet: "no server runs a desktop", "no two hosts share an address".
        `yen.invariants.<name>` gives [Datalog](/query/datalog/) rules over the fleet's facts, as data. A true `[ "bad" … ]` atom is a violation.
      ''
      (docs.file "modules/fleet.nix")
      (docs.file "modules/invariants.nix")
      ''
        A rule is `{ head; pos ? [ ]; neg ? [ ]; }`. An atom is a list `[ rel t… ]`. A term is a string, an int, a bool,
        or a variable `{ var = "X"; }`: every string is a constant. `lt` and `neq` compare two bound terms. A relation you derive
        (other than `bad`) is declared with its arity and an optional `check` on its terms: `yen.relations.reach.arity = 2;`. A derived tuple that fails the check is the error `relation-check`. The facts:
      ''
      (docs.table
        [ "Fact" "Holds when" ]
        [
          [
            "`[ \"scope\" ID ]`, `[ \"kind\" K ID ]`"
            "a scope exists, and its kind"
          ]
          [
            "`[ \"instance\" ID KIND NAME ]`, `[ \"parent\" ID PARENT ]`"
            "the instance a scope holds (a ref names KIND NAME), and the scope above it"
          ]
          [
            "`[ \"has\" ASPECT ID ]`"
            "the aspect is active at the scope"
          ]
          [
            "`[ \"edge\" SINK FROM TO ]`"
            "an element is routed"
          ]
          [
            "`[ \"val\" FIELD ID VALUE ]`"
            "a field has a string, int, bool or path value (a float, function or derivation is an `unencodable` error)"
          ]
          [
            "`[ \"ref\" FIELD ID KIND NAME ]`"
            "a field refers to an instance"
          ]
          [
            "`[ \"error\" CODE FROM ]`"
            "an error record"
          ]
        ]
      )
      ''
        This fleet holds:
      ''
      (docs.value {
        inherit (result.check)
          ok
          violations
          incomplete
          invariants
          ;
      })
      ''
        ## A change that breaks two rules
      ''
      (docs.file "variants/mistakes.nix")
      (docs.value { inherit ((variant "variants/mistakes.nix").check) ok violations; })
      ''
        `result.check.why atom` gives the rules that prove a violation. `whyNot` and `proof` work as in Datalog:
      ''
      (docs.value (
        (variant "variants/mistakes.nix").check.why [
          "bad"
          "same-addr"
          "fleet:main/host:db"
          "fleet:main/host:spare"
        ]
      ))
      (docs.caution "Incomplete is not a pass" ''
        A `bad` atom on a cycle through `not` is undefined. It goes to `incomplete`, and `ok` is false.
      '')
      (docs.tip "Gate changes on it" ''
        [Stage](/agents/stage/) evaluates a change and refuses it when it adds a violation. CI can fail on `check.ok == false`.
      '')
    ];

  checks =
    { result, variant, ... }:
    let
      m = (variant "variants/mistakes.nix").check;
    in
    {
      ok = result.check.ok;
      violations =
        m.violations == [
          [
            "bad"
            "desktop-on-server"
            "fleet:main/host:web"
          ]
          [
            "bad"
            "same-addr"
            "fleet:main/host:db"
            "fleet:main/host:spare"
          ]
        ]
        && !m.ok;
    };
}
