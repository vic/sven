#: lib.batteries.nixos.persist :: { from; root ? ; } -> key value -- impermanence paths from sink from
# impermanence (github:nix-community/impermanence): paths that survive a reboot, from sink `from`. Each element a
# directory, or `{ directories ? [ ]; files ? [ ]; }`. Import the impermanence module in your host.
#   yen.kinds.host.sinks.persist.nixos = nixos.persist { from = yen.kinds.host.sinks.persist; };
{
  from,
  root ? "/persist",
}:
{ sinks, ... }:
let
  b = builtins;
  ps = sinks.${from.__sink};
  unique = b.foldl' (acc: x: if b.elem x acc then acc else acc ++ [ x ]) [ ];
  of =
    k:
    unique (
      b.concatMap (
        p: if b.isString p then (if k == "directories" then [ p ] else [ ]) else p.${k} or [ ]
      ) ps
    );
in
{
  environment.persistence.${root} = {
    directories = of "directories";
    files = of "files";
  };
}
