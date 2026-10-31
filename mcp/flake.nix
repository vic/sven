# yen-mcp, its own flake, written with yen. Serve the fleet in the working directory:
#   nix run github:vic/yen?dir=mcp
# The agent skill that teaches its tools: .claude/skills/yen-mcp/SKILL.md at the top of the repository.
{
  description = "yen-mcp: an MCP server over a yen fleet";

  outputs =
    inputs:
    inputs.yen.lib.mkFlake {
      inherit inputs;
      inherit (inputs.nixpkgs) lib;
    } ./module.nix;

  inputs = {
    nixpkgs.url = "https://nixos.org/channels/nixos-25.05/nixexprs.tar.xz";
    yen.url = "path:..";
  };
}
