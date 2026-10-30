# homebrew from sink `from`: each element `{ casks ? [ ]; brews ? [ ]; masApps ? { }; }`. Any feature gives the
# apps it needs; one darwin module installs them.
#   yen.kinds.mac.sinks.brew.darwin = darwin.homebrew { from = yen.kinds.mac.sinks.brew; };
{ from }:
{ sinks, ... }:
let
  b = builtins;
  es = sinks.${from.__sink};
  unique = b.foldl' (acc: x: if b.elem x acc then acc else acc ++ [ x ]) [ ];
  of = k: unique (b.concatMap (e: e.${k} or [ ]) es);
in
{
  homebrew = {
    enable = true;
    casks = of "casks";
    brews = of "brews";
    masApps = b.foldl' (a: e: a // (e.masApps or { })) { } es;
  };
}
