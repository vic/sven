#: lib.batteries.editors.zed :: { from; } -> key value -- one home module for Zed from the extensions and settings of sink from
# Zed (home-manager `programs.zed-editor`) from sink `from`: `{ extensions ? [ ]; settings ? { }; }` per aspect,
# extensions by name.
#   yen.kinds.user.sinks.zed.homeManager = editors.zed { from = yen.kinds.user.sinks.zed; };
{ from }:
{ sinks, ... }:
let
  b = builtins;
  es = sinks.${from.__sink};
  unique = b.foldl' (acc: x: if b.elem x acc then acc else acc ++ [ x ]) [ ];
in
{
  programs.zed-editor = {
    enable = true;
    extensions = unique (b.concatMap (e: e.extensions or [ ]) es);
    userSettings = b.foldl' (a: e: a // (e.settings or { })) { } es;
  };
}
