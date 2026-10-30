let
  K = (import ../default.nix).lib.krn;
  fives =
    x:
    K.disj [
      (K.eq x 5)
      (fives x)
    ];
  mem = K.runAllFuel 1000 (
    q:
    K.membero q [
      1
      2
      3
    ]
  );
  fd =
    q:
    K.fresh (
      {
        x,
        y,
        z,
      }:
      [
        (K.infd [ x y ] 1 4)
        (K.infd [ z ] 2 8)
        (K.plusfd x y z)
        (K.label [
          x
          y
          z
        ])
        (K.eq q [
          x
          y
          z
        ])
      ]
    );
  spin = x: K.disj [ (spin x) ];
  inf = K.runAllFuel 50 fives;
  two = K.runFuel 2 1000 fives;
  mx = K.maximize 10000 (a: builtins.elemAt a 2) fd;
  mxTiny = K.maximize 3 (a: builtins.elemAt a 2) fd;
  app = K.runAllFuel 200 (
    q:
    K.fresh (
      { a, b }:
      [
        (K.appendo a b (K.fromList [ 1 ]))
        (K.eq q 1)
      ]
    )
  );
  app2 = K.runAllFuel 200 (
    q:
    K.fresh (
      {
        a,
        b,
        c,
      }:
      [
        (K.appendo a b c)
        (K.eq q [
          a
          b
          c
        ])
      ]
    )
  );
  # a fastest test: { expr; expected; }
  eq = expr: expected: { inherit expr expected; };
  checks = {
    infinite-incomplete = {
      complete = eq inf.complete false;
      some = eq (inf.answers != [ ]) true;
      all-five = eq (builtins.all (a: a == 5) inf.answers) true;
    };
    suspension-fuel = {
      complete = eq (K.runAllFuel 50 spin).complete false;
      answers = eq (K.runAllFuel 50 spin).answers [ ];
    };
    infinite-n-complete = {
      complete = eq two.complete true;
      answers = eq two.answers [
        5
        5
      ];
    };
    finite-complete = {
      complete = eq mem.complete true;
      answers = eq mem.answers [
        1
        2
        3
      ];
    };
    finite-low-fuel =
      eq
        (K.runAllFuel 1 (
          q:
          K.membero q [
            1
            2
            3
          ]
        )).complete
        false;
    maximize-best = {
      value = eq mx.value 8;
      best = eq mx.best [
        4
        4
        8
      ];
      complete = eq mx.complete true;
      count = eq mx.count 16;
    };
    maximize-low-fuel = eq mxTiny.complete false;
    appendo-unbounded = {
      complete = eq app2.complete false;
      some = eq (app2.answers != [ ]) true;
    };
    appendo-finite-ok = eq app.complete true;
  };
in
{
  tests = checks;
}
