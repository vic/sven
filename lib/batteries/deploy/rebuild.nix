#: lib.batteries.deploy.rebuild :: { from; pkgs; flake ? ; } -> out value -- apps.<system>.rebuild-<machine>: nixos-rebuild --target-host
# one flake app per machine, the `out` of a sink `from` that reduces with `one` to `{ address; user; buildHost ? ; }`
# (the machine's deploy target; null: no app). The app name is `rebuild-` and the scope name. With a `buildHost`
# the build runs there (`--build-host`).
# `pkgs` is the caller's only dependency: writeShellScript, stdenv.hostPlatform.system and the tool; no nixpkgs lib is used.
#   deploy.out = deploy.rebuild { from = yen.kinds.host.sinks.deploy; inherit pkgs; };
{
  from,
  pkgs,
  flake ? ".",
}:
{ scope, sinks, ... }:
let
  d = sinks.${from.__sink};
  name = "rebuild-${scope.name}";
  arg = s: "'${builtins.replaceStrings [ "'" ] [ "'\\''" ] s}'"; # shell quoting, builtins only
  build = if (d.buildHost or null) == null then "" else "--build-host ${arg d.buildHost} ";
in
if d == null then
  { }
else
  {
    apps.${pkgs.stdenv.hostPlatform.system}.${name} = {
      type = "app";
      program = "${pkgs.writeShellScript name ''
        exec ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --flake ${arg "${flake}#${scope.name}"} \
          --target-host ${arg "${d.user}@${d.address}"} ${build}"$@"
      ''}";
    };
  }
