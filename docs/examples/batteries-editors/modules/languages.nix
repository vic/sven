# Each language aspect gives what both editors need; no editor file lists the languages.
{ yen, inputs, ... }:
let
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
in
{
  yen.aspects.nix-lang = {
    at = yen.kinds.home;
    vscode = {
      extensions = [ pkgs.vscode-extensions.jnoortheen.nix-ide ];
      settings."nix.enableLanguageServer" = true;
    };
    zed.extensions = [ "nix" ];
  };
  yen.aspects.go-lang = {
    at = yen.kinds.home;
    vscode.extensions = [ pkgs.vscode-extensions.golang.go ];
    zed.extensions = [ "go" ];
  };
  # skills from a directory, and an mcp server, in one pool
  yen.aspects.agents = {
    at = yen.kinds.home;
    agent-ext = yen.lib.batteries.ai.skills ../skills ++ [
      {
        type = "mcp";
        name = "github";
      }
    ];
  };
}
