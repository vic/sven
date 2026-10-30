#: lib.batteries.nixos.insecure :: { from; } -> key value -- one permittedInsecurePackages from the names of sink from
# nixpkgs.config does not merge: permittedInsecurePackages loses lists. `from` collects package names; one module allows them.
{ from }:
{ sinks, ... }:
{
  nixpkgs.config.permittedInsecurePackages = builtins.concatLists sinks.${from.__sink};
}
