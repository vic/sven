# The sven docs site, as a sven fleet: every page is an instance, every code block a file under examples/.
# Regenerate the pages: nix run .#write-files. Test the examples: nix eval --impure --file tests.nix failed
{
  description = "sven documentation, generated from tested examples";

  outputs =
    inputs:
    let
      # the docs live in the sven repository: its root is the engine, shaped like the `sven` flake input
      sven = import inputs.self.sourceInfo // {
        inherit (inputs.self.sourceInfo) outPath;
      };
      flake = sven.lib.mkFlake {
        imports = [ (inputs.import-tree ./modules) ];
        _module.args = {
          inputs = inputs // {
            inherit sven;
          };
          inherit (inputs.nixpkgs) lib;
        };
      };
    in
    {
      inherit (flake)
        packages
        checks
        tests
        devShells
        ;
      templates = import ./templates.nix;
    }; # literal names: `self` is readable while the outputs evaluate

  inputs = {
    den.url = "github:denful/den";
    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    files.url = "github:sini/files";
    flake-file.url = "github:denful/flake-file";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    import-tree.url = "github:denful/import-tree";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "https://nixos.org/channels/nixos-25.05/nixexprs.tar.xz";
  };
}
