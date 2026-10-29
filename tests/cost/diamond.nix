# k levels of aspect-ref diamonds: x_i holds where l_i and r_i hold, both read x_(i-1). Without a memo: 2^k reads.
{
  k ? 30,
}:
let
  b = builtins;
  yen = (import ../../default.nix).lib;
in
(yen.eval (
  { yen, ... }:
  {
    yen.kinds.top.spawns.host = _: yen.host;
    yen.kinds.host = { };
    yen.top.t = { };
    yen.host.h = { };
    yen.aspects = {
      x0.at = yen.kinds.host;
    }
    // b.listToAttrs (
      b.concatMap (
        i:
        let
          p = "x${toString (i - 1)}";
        in
        [
          {
            name = "l${toString i}";
            value.at = yen.aspects.${p};
          }
          {
            name = "r${toString i}";
            value.at = yen.aspects.${p};
          }
          {
            name = "x${toString i}";
            value.at = yen.lib.all [
              yen.aspects."l${toString i}"
              yen.aspects."r${toString i}"
            ];
          }
        ]
      ) (b.genList (i: i + 1) k)
    );
  }
)).active."x${toString k}"."top:t/host:h"
