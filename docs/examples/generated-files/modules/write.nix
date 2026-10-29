# flake.nix and README.md, generated from fleet data.
{ sven, lib, ... }:
let
  # one input, in nixfmt's layout: the generated file passes `nixfmt --check` unchanged
  input =
    n: v:
    "    ${n} = {\n"
    + lib.concatStrings (lib.mapAttrsToList (k: x: "      ${k} = ${builtins.toJSON x};\n") v)
    + "    };";
  hosts = lib.filter (s: s.kind == "host") sven.lib.graph.scopes;
in
{
  sven.aspects.write = {
    at = sven.kinds.fleet;
    files =
      { inputs, ... }:
      {
        files.file."flake.nix".text = ''
          # Generated from the `inputs` sink. Edit modules/, then run: nix run .#write-files
          {
            outputs =
              inputs:
              inputs.sven.lib.mkFlake {
                imports = [ (inputs.import-tree ./modules) ];
                _module.args = {
                  inherit inputs;
                  inherit (inputs.nixpkgs) lib;
                };
              };

            inputs = {
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList input inputs)}
            };
          }
        '';
        files.file."README.md".text = ''
          # My fleet

          Generated from the fleet. Hosts: ${lib.concatMapStringsSep ", " (s: "`${s.name}`") hosts}.
        '';
      };
  };
}
