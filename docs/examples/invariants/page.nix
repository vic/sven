{
  title = "Invariants";
  description = "Rules that must hold across the whole fleet, checked before deploy: `r.check`.";
  section = "query";
  order = 5;

  body =
    {
      docs,
      r,
      variant,
      ...
    }:
    [
      ''
        An invariant is a rule about the whole fleet: "no server runs a desktop", "no two hosts share an address".
        `yen.invariants.<name>` gives [Datalog](/query/datalog/) rules over the fleet's facts. A true `bad:` atom is a violation.
      ''
      (docs.file "modules/fleet.nix")
      (docs.fileWith "{5-7,9-12}" "modules/invariants.nix")
      ''
        The function gets `scopes`, `graph`, `active` and `facts`. Facts are ground atoms:
      ''
      (docs.table
        [ "Fact" "Holds when" ]
        [
          [
            "`scope:ID`, `kind:K:ID`"
            "a scope exists, and its kind"
          ]
          [
            "`has:ASPECT:ID`"
            "the aspect is active at the scope"
          ]
          [
            "`edge:SINK:FROM:TO`"
            "an element is routed"
          ]
          [
            "`val:FIELD:ID:VALUE`"
            "a field has a scalar value"
          ]
          [
            "`ref:FIELD:ID:KIND:NAME`"
            "a field refers to an instance"
          ]
          [
            "`error:CODE:FROM`"
            "an error record"
          ]
        ]
      )
      ''
        This fleet holds:
      ''
      (docs.value {
        inherit (r.check)
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
        `r.check.why atom` gives the rules that prove a violation. `whyNot` and `proof` work as in Datalog:
      ''
      (docs.value ((variant "variants/mistakes.nix").check.why "bad:same-addr:db:spare"))
      (docs.caution "Incomplete is not a pass" ''
        A `bad:` atom on a cycle through `not` is undefined. It goes to `incomplete`, and `ok` is false.
      '')
      (docs.tip "Gate changes on it" ''
        [Stage](/agents/stage/) evaluates a change and refuses it when it adds a violation. CI can fail on `check.ok == false`.
      '')
    ];

  checks =
    { r, variant, ... }:
    let
      m = (variant "variants/mistakes.nix").check;
    in
    {
      ok = r.check.ok;
      violations =
        m.violations == [
          "bad:desktop-on-server:web"
          "bad:same-addr:db:spare"
        ]
        && !m.ok;
    };
}
