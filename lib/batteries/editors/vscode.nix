# VS Code (home-manager `programs.vscode`) from sink `from`: language and tool aspects give
# `{ extensions ? [ ]; settings ? { }; }`; one home module merges them. `profile` names the vscode profile.
#   yen.kinds.user.sinks.vscode.homeManager = editors.vscode { from = yen.kinds.user.sinks.vscode; };
{
  from,
  profile ? "default",
}:
{ sinks, ... }:
let
  b = builtins;
  es = sinks.${from.__sink};
  unique = b.foldl' (acc: x: if b.elem x acc then acc else acc ++ [ x ]) [ ];
in
{
  programs.vscode = {
    enable = true;
    profiles.${profile} = {
      extensions = unique (b.concatMap (e: e.extensions or [ ]) es);
      userSettings = b.foldl' (a: e: a // (e.settings or { })) { } es;
    };
  };
}
