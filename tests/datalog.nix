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

  checks = {
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
    proofCycleMarker =
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
      (D.proof r (D.wfs r) "p").pos == [
        {
          atom = "q";
          rule = {
            head = "q";
            pos = [ "p" ];
          };
          pos = [
            {
              atom = "p";
              cycle = true;
            }
          ];
          neg = [ ];
        }
      ];

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
