# yen-mcp: the Rust server, wrapped with its tool.nix and git. Nix itself comes from the caller's PATH: its version,
# its store. The mcp flake and the reference fleet both build this one derivation.
{
  lib,
  rustPlatform,
  makeWrapper,
  git,
}:
rustPlatform.buildRustPackage {
  pname = "yen-mcp";
  version = "0.1.0";
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./Cargo.toml
      ./Cargo.lock
      ./src
    ];
  };
  cargoLock.lockFile = ./Cargo.lock;
  nativeBuildInputs = [ makeWrapper ];
  postInstall = ''
    wrapProgram $out/bin/yen-mcp \
      --set-default YEN_TOOL_NIX ${./tool.nix} \
      --suffix PATH : ${lib.makeBinPath [ git ]}
  '';
  meta = {
    description = "MCP server (JSON-RPC 2.0 on stdio) over the yen fleet in the working directory";
    mainProgram = "yen-mcp";
  };
}
