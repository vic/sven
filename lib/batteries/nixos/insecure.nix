# nixpkgs.config does not merge: permittedInsecurePackages loses lists. `from` collects package names; one module allows them.
{ from }:
{ sinks, ... }:
{
  nixpkgs.config.permittedInsecurePackages = builtins.concatLists sinks.${from.__sink};
}
