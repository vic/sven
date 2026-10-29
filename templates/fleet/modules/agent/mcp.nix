# The MCP server as a flake app: `nix run .#yen-mcp` from the fleet directory serves the fleet in $PWD on stdio.
# The script and its tool.nix are copied to the store; the fleet is read from the working tree, so answers follow edits.
{
  yen,
  lib,
  inputs,
  ...
}:
let
  app =
    system:
    let
      pkgs = inputs.nixpkgs.legacyPackages.${system};
    in
    pkgs.writeShellApplication {
      name = "yen-mcp";
      runtimeInputs = [
        pkgs.jq
        pkgs.coreutils
        pkgs.git
      ]; # nix itself comes from the caller's PATH: its version, its store
      text = ''
        export YEN_FLEET="''${YEN_FLEET:-$PWD}"
        exec ${../../mcp}/yen-mcp.sh "$@"
      '';
    };
in
{
  yen.aspects.mcp-app = {
    at = yen.kinds.fleet;
    out =
      { ... }:
      {
        apps = lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system: {
          yen-mcp = {
            type = "app";
            program = "${app system}/bin/yen-mcp";
            meta.description = "yen MCP server over the fleet in the working directory";
          };
        });
      };
  };
}
