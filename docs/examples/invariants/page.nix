{
  title = "Invariants";
  description = "Rules that must hold across the whole fleet, checked before deploy: `result.check`.";
  section = "query";
  order = 4;

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
        `yen.invariants.<name>` gives [Datalog](/query/datalog/) rules over the fleet's facts. A true `[ "bad" … ]` atom is a violation.
      ''
      (docs.file "modules/fleet.nix")
      (docs.file "modules/invariants.nix")
      ''
        A rule is a function of its variables: `{ H }: { bad = H; pos = [ … ]; neg = [ … ]; }`. Each argument is a
        variable. A literal comes by reference from `yen.facts`, never by name: `host.addr A X` (a field holds X; for a ref
        field, X is a scope of the instance it refers to, and a ref such as `yen.env.prod` is a constant), `kind yen.kinds.host H`,
        `has yen.aspects.desktop H`, `instance H yen.host.db`, `parent H P`, and `lt` and `neq`, which compare two bound terms.
        A string, an int or a bool is a constant. `bad = H` makes the violation `[ "bad" <invariant> H ]`. A typo in a field,
        an aspect or a variable is an evaluation error, so a rule can never silently match nothing.

        A relation you derive is declared with its arity and an optional `check` on its terms:
        `yen.relations.reach.arity = 2;`. Call it by reference, `yen.relations.reach A B`, as a literal or as a rule's
        `head`. A derived tuple that fails the check is the error `relation-check`.
        A relation can also be decided by a function on bound terms: `yen.relations.digits = { arity = 1; holds = ts: …; }`,
        or by a type: `yen.relations.port.type = yen.kinds.host.fields.port;`, true when the term passes the type's check.
        Such a relation is never a fact and never a rule head, and its variables must be bound by other atoms. A
        `holds` answer that is not a bool is the error `external-not-bool`. The facts the literals read:
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
          "unique-addr"
          "fleet:main/host:db"
          "fleet:main/host:spare"
        ]
      ))
      (docs.caution "Incomplete is not a pass" ''
        A `bad` atom on a cycle through `not` is undefined. It goes to `incomplete`, and `ok` is false.
      '')
      ''
        ## A certificate with every verdict

        `result.check.certificate` gives each decided atom its stage in the well-founded model, and each true atom the
        rule that proves it (Van Gelder, Ross, Schlipf 1991). A small checker in plain Nix,
        `yen.lib.datalog.checkCertificate`, accepts it only when every true atom has a rule decided before it and every
        rule of a false atom is blocked by an atom decided no later. `result.check.certified` is true when the checker
        accepts the certificate and it states the same verdict. No stratification is needed, and an undefined `bad`
        atom is in neither list.
      ''
      (docs.value { inherit (result.check) certified; })
      ''
        `result.check.seal` binds the verdict and its certificate to hashes of the engine, the rules and the facts.
        Anyone can check it by evaluating the fleet again: `result.check.verify seal` gives `{ ok = true; }`, or
        `{ ok = false; why; }` with `why` one of `engine`, `rules`, `facts`, `certificate` or `verdict`.
        `result.check.from atom` tells where a fact comes from: the files that declare it, or an edge's origin.
        Where a fact comes from is never part of the fact.

        A field that holds an attrset gives no `val` fact. When a rule reads that field through an even number of
        `not` from `bad`, a missing fact could hide a violation, so `result.check.opaque` names the field and its scopes
        and `ok` is false. Read under one `not`, a missing fact can only add a violation, so it is safe.
      ''
      (docs.tip "Gate changes on it" ''
        [Stage](/agents/stage/) evaluates a change and refuses it when it adds a violation. CI can fail on `check.ok == false`.
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
    let
      m = (variant "variants/mistakes.nix").check;
    in
    {
      ok = yes (result.check.ok);
      certified = {
        t1 = yes (result.check.certified);
        t2 = yes ((variant "variants/mistakes.nix").check.certified);
      };
      sealed = {
        t1 = eq (result.check.verify result.check.seal) ({
          ok = true;
        });
        t2 = eq ((variant "variants/mistakes.nix").check.verify result.check.seal) ({
          ok = false;
          why = "facts";
        });
      };
      violations = {
        t1 = eq (m.violations) ([
          [
            "bad"
            "no-desktop-on-servers"
            "fleet:main/host:web"
          ]
          [
            "bad"
            "unique-addr"
            "fleet:main/host:db"
            "fleet:main/host:spare"
          ]
        ]);
        t2 = no (m.ok);
      };
    };
}
