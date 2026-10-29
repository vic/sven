# n hosts each read one fleet sink (`pool`) of n elements with a costly reduce. One reduction: ~n steps. One per read: ~n*n.
{
  n ? 150,
}:
let
  b = builtins;
  yen = (import ../../default.nix).lib;
in
let
  r = yen.eval (
    { yen, ... }:
    {
      yen.kinds.top = {
        spawns.host = _: yen.host;
        sinks.pool.reduce = es: {
          value = b.foldl' (a: e: a + e.value) 0 es;
          errors = [ ];
        };
      };
      yen.kinds.host.sinks.out = { };
      yen.top.t = { };
      yen.host = b.listToAttrs (
        b.genList (i: {
          name = "h${toString i}";
          value = { };
        }) n
      );
      yen.aspects.give = {
        at = yen.kinds.host;
        pool = { host, ... }: b.stringLength host.name;
      };
      yen.aspects.read = {
        at = yen.kinds.host;
        out = { pool, ... }: pool;
      };
    }
  );
in
b.foldl' (a: v: a + b.head v) 0 (b.attrValues r.reduced.out)
