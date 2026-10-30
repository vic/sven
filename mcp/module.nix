# The mcp flake as a yen fleet: one `server` instance; its `out` sink gives the package and the app per system.
{
  yen,
  lib,
  inputs,
  ...
}:
let
  systems = [
    "x86_64-linux"
    "aarch64-linux"
    "x86_64-darwin"
    "aarch64-darwin"
  ];
  server = system: inputs.nixpkgs.legacyPackages.${system}.callPackage ./package.nix { };
in
{
  yen.kinds.server = {
    spawns = { };
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.server.yen-mcp = { };
  yen.aspects.package = {
    at = yen.kinds.server;
    out =
      { ... }:
      {
        packages = lib.genAttrs systems (system: {
          yen-mcp = server system;
          default = server system;
        });
        apps = lib.genAttrs systems (system: {
          default = {
            type = "app";
            program = lib.getExe (server system);
            meta.description = "yen MCP server over the fleet in the working directory";
          };
        });
      };
  };
  yen.flake = { out, ... }: out;
}
