# datalog oracles. Run: nix-instantiate --eval --strict tests/datalog.nix -A failed   (expect [ ])
let
  D = (import ../default.nix).lib.datalog;
  b = builtins;
  depth =
    p:
    if p ? pos && p.pos != [ ] then
      1 + b.foldl' (m: x: if x > m then x else m) 0 (map depth p.pos)
    else
      1;

  chain = [
    {
      head = "c";
      pos = [ "b" ];
    }
    {
      head = "b";
      pos = [ "a" ];
    }
    { head = "a"; }
  ];
  mchain = D.wfs chain;
  serves = [
    {
      head = "serves:x";
      pos = [ "web:x" ];
      neg = [ "drained:x" ];
    }
    { head = "web:x"; }
    { head = "drained:x"; }
  ];
  mserves = D.wfs serves;
  even = [
    {
      head = "a";
      neg = [ "b" ];
    }
    {
      head = "b";
      neg = [ "a" ];
    }
  ];
  pcycle = [
    {
      head = "p";
      pos = [ "q" ];
    }
    {
      head = "q";
      pos = [ "p" ];
    }
  ];

  # rung 3 (vic/formally-verified.md section 5): staged certificates, checked by a small plain-Nix checker
  r = head: pos: neg: { inherit head pos neg; };
  t = atom: stage: rule: { inherit atom stage rule; };
  u = atom: stage: { inherit atom stage; };
  cyc = [
    (r "a" [ "b" ] [ ])
    (r "b" [ "a" ] [ ])
    (r "a" [ "f" ] [ ])
    (r "f" [ ] [ ])
  ];
  choice = [
    (r "bad" [ ] [ "ok" ])
    (r "ok" [ ] [ "bad" ])
  ];
  fw = [
    (r "bad" [ "open" ] [ "fw" ])
    (r "open" [ ] [ ])
    (r "fw" [ ] [ ])
  ];
  self = [ (r "p" [ ] [ "p" ]) ];
  valid = rules: cert: (D.checkCertificate rules cert).valid;
  # a fastest test: { expr; expected; }
  eq = expr: expected: { inherit expr expected; };
  yes = x: eq x true;
  no = x: eq x false;
  certTable = {
    # a:-b. b:-a. a:-f. f.: a ranked through f is accepted; through b (a later stage) it is not
    cycle-through-f = yes (
      valid cyc {
        true = [
          (t "f" 0 (b.elemAt cyc 3))
          (t "a" 1 (b.elemAt cyc 2))
          (t "b" 2 (b.elemAt cyc 1))
        ];
        false = [ ];
      }
    );
    cycle-through-b = no (
      valid cyc {
        true = [
          (t "f" 0 (b.elemAt cyc 3))
          (t "a" 1 (b.elemAt cyc 0))
          (t "b" 2 (b.elemAt cyc 1))
        ];
        false = [ ];
      }
    );
    # bad:-not ok. ok:-not bad.: no staging decides it
    choice-bad-absent = no (
      valid choice {
        true = [ (t "ok" 1 (b.elemAt choice 1)) ];
        false = [ (u "bad" 0) ];
      }
    );
    choice-bad-true = no (
      valid choice {
        true = [ (t "bad" 1 (b.elemAt choice 0)) ];
        false = [ (u "ok" 0) ];
      }
    );
    # bad:-open,not fw. open. fw.: absence of bad, at stage 1 and not at stage 0
    absence-ok = yes (
      valid fw {
        true = [
          (t "open" 0 (b.elemAt fw 1))
          (t "fw" 0 (b.elemAt fw 2))
        ];
        false = [ (u "bad" 1) ];
      }
    );
    absence-early = no (
      valid fw {
        true = [
          (t "open" 0 (b.elemAt fw 1))
          (t "fw" 0 (b.elemAt fw 2))
        ];
        false = [ (u "bad" 0) ];
      }
    );
    # p:-not p.: p cannot be both
    self-both = no (
      valid self {
        true = [ (t "p" 1 (b.head self)) ];
        false = [ (u "p" 0) ];
      }
    );
    # a rule the program does not have is no proof
    foreign-rule = no (
      valid fw {
        true = [
          (t "open" 0 (b.elemAt fw 1))
          (t "fw" 0 (b.elemAt fw 2))
          (t "bad" 1 (r "bad" [ "open" ] [ ]))
        ];
        false = [ ];
      }
    );
  };
  checks = {
    cert-table = certTable;
    # the prover's certificate passes the checker, and its verdict is the well-founded model's
    certify-agrees =
      b.mapAttrs
        (
          _: p:
          let
            c = D.certify p;
            m = D.wfs p;
          in
          {
            valid = yes (D.checkCertificate p c).valid;
            true = eq (b.sort b.lessThan (map (e: e.atom) c.true)) (b.sort b.lessThan m.true);
            false = eq (b.sort b.lessThan (map (e: e.atom) c.false)) (b.sort b.lessThan m.false);
          }
        )
        {
          inherit
            cyc
            fw
            self
            choice
            chain
            serves
            ;
        };
    # D4: the proof of a true atom follows strictly smaller stages, never a cycle
    proof-no-cycle =
      let
        p = D.proof cyc (D.wfs cyc) "a";
      in
      {
        rule = eq p.rule (b.elemAt cyc 2);
        first = eq (b.head p.pos).atom "f";
        no-cycle = no (b.head p.pos ? cycle);
      };
    # the grounder: { var = "X"; } binds over the facts and the heads the rules can derive; neq and lt filter
    ground-vars =
      let
        v = x: { var = x; };
        facts = [
          [
            "host"
            "a"
          ]
          [
            "host"
            "b"
          ]
          [
            "addr"
            "a"
            "10.0.0.1"
          ]
          [
            "addr"
            "b"
            "10.0.0.1"
          ]
          [
            "edge"
            "a"
            "b"
          ]
          [
            "edge"
            "b"
            "c"
          ]
          [
            "edge"
            "c"
            "d"
          ]
        ];
        rules = [
          {
            head = [
              "bad"
              "clash"
              (v "A")
              (v "B")
            ];
            pos = [
              [
                "addr"
                (v "A")
                (v "X")
              ]
              [
                "addr"
                (v "B")
                (v "X")
              ]
              [
                "lt"
                (v "A")
                (v "B")
              ]
            ];
          }
          {
            head = [
              "reach"
              (v "X")
              (v "Y")
            ];
            pos = [
              [
                "edge"
                (v "X")
                (v "Y")
              ]
            ];
          }
          {
            head = [
              "reach"
              (v "X")
              (v "Z")
            ];
            pos = [
              [
                "reach"
                (v "X")
                (v "Y")
              ]
              [
                "edge"
                (v "Y")
                (v "Z")
              ]
            ];
          }
          {
            head = [
              "bad"
              "lonely"
              (v "H")
            ];
            pos = [
              [
                "host"
                (v "H")
              ]
            ];
            neg = [
              [
                "reach"
                (v "H")
                "d"
              ]
            ]; # a reaches d in 3 steps: the bound must iterate
          }
        ];
        m = D.wfs (D.ground rules facts ++ D.facts facts);
      in
      eq (b.filter (a: b.head a == "bad") m.true) [
        [
          "bad"
          "clash"
          "a"
          "b"
        ]
      ];
    # typed atoms: a tuple is one atom, keyed by toJSON; two tuples that spell one colon string stay two (D1)
    tuple-atoms =
      let
        rs = [
          {
            head = [
              "val"
              "tag"
              "a"
              "b:1"
            ];
          }
          {
            head = [
              "bad"
              "x"
            ];
            pos = [
              [
                "val"
                "tag"
                "a:b"
                "1"
              ]
            ];
          }
          {
            head = [
              "ok"
              1
              true
            ];
            pos = [
              [
                "val"
                "tag"
                "a"
                "b:1"
              ]
            ];
            neg = [
              [
                "bad"
                "x"
              ]
            ];
          }
        ];
        m = D.wfs rs;
        ok = [
          "ok"
          1
          true
        ];
      in
      {
        holds = yes (m.holds ok);
        bad-not = no (
          m.holds [
            "bad"
            "x"
          ]
        );
        in-true = yes (b.elem ok m.true);
        why = eq (D.why rs m ok) [ (b.elemAt rs 2) ];
        proof = eq (D.proof rs m ok).atom ok;
      };
    proofChainDepth = eq (depth (D.proof chain mchain "c")) 3;
    proofChainShape = {
      c = eq (D.proof chain mchain "c").pos [ (D.proof chain mchain "b") ];
      a = eq (D.proof chain mchain "a").pos [ ];
    };
    proofFalse = eq ((D.proof serves mserves "serves:x").status or "") "false";
    proofUndefined = eq ((D.proof even (D.wfs even) "a").status or "") "undefined";
    proofPosCycleFalse = eq ((D.proof pcycle (D.wfs pcycle) "p").status or "") "false";
    proofNoCycle =
      let
        r = [
          {
            head = "p";
            pos = [ "q" ];
          }
          {
            head = "q";
            pos = [ "p" ];
          }
          { head = "p"; }
        ];
      in
      # D4: p is a fact (stage 0), so its proof is the fact, never p, q, p again
      eq (D.proof r (D.wfs r) "p") {
        atom = "p";
        rule = {
          head = "p";
        };
        pos = [ ];
        neg = [ ];
      };

    whyNotBlocking = eq (b.map (x: x.blocking) (D.whyNot serves mserves "serves:x")) [
      [ "drained:x" ]
    ];
    whyNotMissingEmpty = eq (b.map (x: x.missing) (D.whyNot serves mserves "serves:x")) [ [ ] ];
    whyNotMissing = eq (b.map (x: x.missing) (
      D.whyNot chain (D.wfs [
        {
          head = "c";
          pos = [ "b" ];
        }
      ]) "c"
    )) [ [ "b" ] ];
    whyNotTrue = eq (D.whyNot chain mchain "c") [ ];
    whyNotNoRule = eq (D.whyNot chain mchain "zzz") [
      {
        rule = null;
        reason = "no rule has this head";
      }
    ];
    whyNotUndefined = eq (b.map (x: x.undefinedBody) (D.whyNot even (D.wfs even) "a")) [ [ "b" ] ];

    judgeEven = eq (D.judge even "a" "b") "unknown";
    judgeSupported = eq (D.judge (D.facts [ "p" ]) "p" "q") "supported";
    judgeRefuted = eq (D.judge (D.facts [ "p" ]) "q" "p") "refuted";
    judgeBoth = eq (D.judge (D.facts [
      "p"
      "q"
    ]) "p" "q") "both";
    judgeNeither = eq (D.judge [ ] "p" "q") "neither";
  };
in
{
  # fastest: tests.<suite>.<test> = { expr; expected; }
  tests = checks;
}
