# More repo files and a numtide/devshell whose commands come from any aspect.
{ yen, inputs, ... }:
let
  inherit (yen.lib.batteries) files github devshell;
in
{
  # TOML and YAML from Nix values, as repo files
  yen.aspects.config-files = {
    at = yen.kinds.repo;
    files.files.file = {
      "taplo.toml".text = files.toml { } {
        formatting.align_entries = true;
      };
      ".github/dependabot.yml".text = github.yaml {
        version = 2;
        updates = [
          {
            package-ecosystem = "github-actions";
            directory = "/";
            schedule.interval = "weekly";
          }
        ];
      };
    };
  };
  # each aspect gives a list of commands; the shell shows them in its menu
  yen.kinds.repo.sinks.commands.out = devshell.numtide {
    from = yen.kinds.repo.sinks.commands;
    inherit (inputs) devshell;
    systems = [ "x86_64-linux" ];
    pkgsOf = s: inputs.nixpkgs.legacyPackages.${s};
    name = "repo";
    packages = pkgs: [ pkgs.jq ];
    shell = "repo"; # the system scope gives `default`
  };
  yen.aspects.write-command = {
    at = yen.kinds.repo;
    commands = [
      {
        name = "write";
        help = "write the generated files";
        command = "nix run .#write-files";
      }
    ];
  };
}
