# a numtide/devshell per system, its commands from sink `from` (each element a list of commands): the value of
# the sink's `out` key. `packages` and `pkgsOf` are functions of the system.
#   yen.kinds.repo.sinks.commands.out = devshell.numtide { from = yen.kinds.repo.sinks.commands;
#     inherit (inputs) devshell; systems = [ "x86_64-linux" ]; pkgsOf = s: inputs.nixpkgs.legacyPackages.${s};
#     name = "repo"; packages = pkgs: [ pkgs.git ]; };
{
  from,
  devshell,
  systems,
  pkgsOf,
  name,
  packages ? _: [ ],
}:
{ sinks, ... }:
{
  devShells = builtins.listToAttrs (
    map (system: {
      name = system;
      value.default = devshell.legacyPackages.${system}.mkShell {
        inherit name;
        packages = packages (pkgsOf system);
        commands = builtins.concatLists sinks.${from.__sink};
      };
    }) systems
  );
}
