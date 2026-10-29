# The docs oracles. Every page has checks on its example fleet.
#   nix eval --impure --file tests.nix failed       # [ ]: yen queries only, fast
#   nix eval --impure --file tests.nix e2e.failed   # [ ]: real NixOS and home-manager evaluations
let
  inherit (builtins)
    attrNames
    concatLists
    filter
    getFlake
    ;
  tests = (getFlake "git+file://${toString ../.}?dir=docs").tests; # git: tracked files only, never node_modules
  failedOf =
    k:
    concatLists (
      map (p: map (c: "${p}/${c}") (filter (c: !tests.${p}.${k}.${c}) (attrNames tests.${p}.${k}))) (
        attrNames tests
      )
    );
in
{
  failed = failedOf "fast";
  e2e.failed = failedOf "e2e";
}
