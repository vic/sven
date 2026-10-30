# The MCP server as a flake app: `nix run .#yen-mcp` from the fleet directory serves the fleet in $PWD on stdio.
# A small Rust binary (mcp/server); its tool.nix is copied to the store. The fleet is read from the working tree,
# so answers follow edits.
{
  yen,
  lib,
  inputs,
  ...
}:
let
  server =
    system:
    let
      pkgs = inputs.nixpkgs.legacyPackages.${system};
    in
    pkgs.rustPlatform.buildRustPackage {
      pname = "yen-mcp";
      version = "0.1.0";
      src = ../../mcp/server;
      cargoLock.lockFile = ../../mcp/server/Cargo.lock;
      nativeBuildInputs = [ pkgs.makeWrapper ];
      # nix itself comes from the caller's PATH: its version, its store
      postInstall = ''
        wrapProgram $out/bin/yen-mcp \
          --set-default YEN_TOOL_NIX ${../../mcp/tool.nix} \
          --suffix PATH : ${lib.makeBinPath [ pkgs.git ]}
      '';
      meta.mainProgram = "yen-mcp";
    };
  systems = [
    "x86_64-linux"
    "aarch64-linux"
  ];
in
{
  yen.aspects.mcp-app = {
    at = yen.kinds.fleet;
    out =
      { ... }:
      {
        packages = lib.genAttrs systems (system: {
          yen-mcp = server system;
        });
        apps = lib.genAttrs systems (system: {
          yen-mcp = {
            type = "app";
            program = "${server system}/bin/yen-mcp";
            meta.description = "yen MCP server over the fleet in the working directory";
          };
        });
      };
  };
}
