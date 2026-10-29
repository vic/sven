# Batteries: functions from roles to a yen module. Generic ones at the top; a domain's batteries under its name.
# A battery names no kind, sink, aspect or field: the user passes each name, in its own words.
import ./generic.nix // { nixos = import ./nixos.nix; }
