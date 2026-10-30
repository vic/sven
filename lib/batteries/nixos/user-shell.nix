#: lib.batteries.nixos.user-shell :: { shell; } -> key value -- the scope account gets the login shell that shell reads
# the scope's account gets a login shell, and the shell is enabled (bash needs nothing). `shell` reads the shell's
# package name from the scope (Den's user-shell).
#   yen.aspects.shells = { at = yen.kinds.user; nixos = nixos.user-shell { shell = u: u.shell; }; };
{ shell }:
{ scope, ... }:
{ pkgs, ... }:
let
  sh = shell scope;
in
{
  users.users.${scope.name}.shell = pkgs.${sh};
}
// (if sh == "bash" then { } else { programs.${sh}.enable = true; })
