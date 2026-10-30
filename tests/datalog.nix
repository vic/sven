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
  certTable = {
    # a:-b. b:-a. a:-f. f.: a ranked through f is accepted; through b (a later stage) it is not
    cycle-through-f = valid cyc {
      true = [
        (t "f" 0 (b.elemAt cyc 3))
        (t "a" 1 (b.elemAt cyc 2))
        (t "b" 2 (b.elemAt cyc 1))
      ];
      false = [ ];
    };
    cycle-through-b =
      !valid cyc {
        true = [
          (t "f" 0 (b.elemAt cyc 3))
          (t "a" 1 (b.elemAt cyc 0))
          (t "b" 2 (b.elemAt cyc 1))
        ];
        false = [ ];
      };
    # bad:-not ok. ok:-not bad.: no staging decides it
    choice-bad-absent =
      !valid choice {
        true = [ (t "ok" 1 (b.elemAt choice 1)) ];
        false = [ (u "bad" 0) ];
      };
    choice-bad-true =
      !valid choice {
        true = [ (t "bad" 1 (b.elemAt choice 0)) ];
        false = [ (u "ok" 0) ];
      };
    # bad:-open,not fw. open. fw.: absence of bad, at stage 1 and not at stage 0
    absence-ok = valid fw {
      true = [
        (t "open" 0 (b.elemAt fw 1))
        (t "fw" 0 (b.elemAt fw 2))
      ];
      false = [ (u "bad" 1) ];
    };
    absence-early =
      !valid fw {
        true = [
          (t "open" 0 (b.elemAt fw 1))
          (t "fw" 0 (b.elemAt fw 2))
        ];
        false = [ (u "bad" 0) ];
      };
    # p:-not p.: p cannot be both
    self-both =
      !valid self {
        true = [ (t "p" 1 (b.head self)) ];
        false = [ (u "p" 0) ];
      };
    # a rule the program does not have is no proof
    foreign-rule =
      !valid fw {
        true = [
          (t "open" 0 (b.elemAt fw 1))
          (t "fw" 0 (b.elemAt fw 2))
          (t "bad" 1 (r "bad" [ "open" ] [ ]))
        ];
        false = [ ];
      };
  };
  checks = {
    cert-table = b.all (n: certTable.${n}) (b.attrNames certTable);
    # the prover's certificate passes the checker, and its verdict is the well-founded model's
    certify-agrees =
      b.all
        (
          p:
          let
            c = D.certify p;
            v = D.checkCertificate p c;
            m = D.wfs p;
          in
          v.valid
          && b.sort b.lessThan (map (e: e.atom) c.true) == b.sort b.lessThan m.true
          && b.sort b.lessThan (map (e: e.atom) c.false) == b.sort b.lessThan m.false
        )
        [
          cyc
          fw
          self
          choice
          chain
          serves
        ];
    # D4: the proof of a true atom follows strictly smaller stages, never a cycle
    proof-no-cycle =
      let
        p = D.proof cyc (D.wfs cyc) "a";
      in
      p.rule == b.elemAt cyc 2 && (b.head p.pos).atom == "f" && !(b.head p.pos ? cycle);
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
      b.filter (a: b.head a == "bad") m.true == [
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
      in
      m.holds [
        "ok"
        1
        true
      ]
      && !(m.holds [
        "bad"
        "x"
      ])
      && b.elem [ "ok" 1 true ] m.true
      &&
        D.why rs m [
          "ok"
          1
          true
        ] == [ (b.elemAt rs 2) ]
      &&
        (D.proof rs m [
          "ok"
          1
          true
        ]).atom == [
          "ok"
          1
          true
        ];
    proofChainDepth = depth (D.proof chain mchain "c") == 3;
    proofChainShape =
      (D.proof chain mchain "c").pos == [ (D.proof chain mchain "b") ]
      && (D.proof chain mchain "a").pos == [ ];
    proofFalse = (D.proof serves mserves "serves:x").status or "" == "false";
    proofUndefined = (D.proof even (D.wfs even) "a").status or "" == "undefined";
    proofPosCycleFalse = (D.proof pcycle (D.wfs pcycle) "p").status or "" == "false";
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
      (D.proof r (D.wfs r) "p") == {
        atom = "p";
        rule = {
          head = "p";
        };
        pos = [ ];
        neg = [ ];
      };

    whyNotBlocking = b.map (x: x.blocking) (D.whyNot serves mserves "serves:x") == [ [ "drained:x" ] ];
    whyNotMissingEmpty = b.map (x: x.missing) (D.whyNot serves mserves "serves:x") == [ [ ] ];
    whyNotMissing =
      b.map (x: x.missing) (
        D.whyNot chain (D.wfs [
          {
            head = "c";
            pos = [ "b" ];
          }
        ]) "c"
      ) == [ [ "b" ] ];
    whyNotTrue = D.whyNot chain mchain "c" == [ ];
    whyNotNoRule =
      D.whyNot chain mchain "zzz" == [
        {
          rule = null;
          reason = "no rule has this head";
        }
      ];
    whyNotUndefined = b.map (x: x.undefinedBody) (D.whyNot even (D.wfs even) "a") == [ [ "b" ] ];

    judgeEven = D.judge even "a" "b" == "unknown";
    judgeSupported = D.judge (D.facts [ "p" ]) "p" "q" == "supported";
    judgeRefuted = D.judge (D.facts [ "p" ]) "q" "p" == "refuted";
    judgeBoth =
      D.judge (D.facts [
        "p"
        "q"
      ]) "p" "q" == "both";
    judgeNeither = D.judge [ ] "p" "q" == "neither";
  };
in
{
  inherit checks;
  failed = b.filter (n: !checks.${n}) (b.attrNames checks);
}
