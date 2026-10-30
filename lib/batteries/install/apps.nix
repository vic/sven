#: lib.batteries.install.apps :: { from; pkgs; report; target; flake ? ; } -> out value -- apps.<system>.install-<machine>: nixos-anywhere with the disko layout and the facter report
# one flake app per machine that holds an element of sink `from` (its disk layout), the `out` of that sink at the
# machine. The app name is `install-` and the scope name. It runs nixos-anywhere on `flake#<machine>` (the layout is
# in the machine's configuration), at `target scope` (`root@host`), and writes the facter report to `report scope`.
# `pkgs` is the caller's only dependency: writeShellScript, stdenv.hostPlatform.system and the tool; no nixpkgs lib is used.
#   out = install.apps { from = yen.kinds.host.sinks.disks; inherit pkgs; report = h: "./facter/${h.name}.json";
#     target = h: "root@${h.addr}"; };
{
  from,
  pkgs,
  report,
  target,
  flake ? ".",
}:
{ scope, sinks, ... }:
let
  name = "install-${scope.name}";
  arg = s: "'${builtins.replaceStrings [ "'" ] [ "'\\''" ] s}'"; # shell quoting, builtins only
in
if sinks.${from.__sink} == { } then
  { }
else
  {
    apps.${pkgs.stdenv.hostPlatform.system}.${name} = {
      type = "app";
      program = "${pkgs.writeShellScript name ''
        exec ${pkgs.nixos-anywhere}/bin/nixos-anywhere --flake ${arg "${flake}#${scope.name}"} \
          --generate-hardware-config nixos-facter ${arg (toString (report scope))} \
          --target-host ${arg (target scope)} "$@"
      ''}";
    };
  }
