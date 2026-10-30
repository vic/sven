# The yen docs site, as a yen fleet: every page is an instance, every code block a file under examples/.
# Regenerate the pages: nix run .#write-files. Test the examples: fastest --flake ".?dir=docs#tests" fast (in the devshell: docs-test)
{
  description = "yen documentation, generated from tested examples";

  outputs =
    inputs:
    let
      # the docs live in the yen repository: its root is the engine, shaped like the `yen` flake input
      yen = import inputs.self.sourceInfo // {
        inherit (inputs.self.sourceInfo) outPath;
      };
      flake = yen.lib.mkFlake {
        imports = [ (inputs.import-tree ./modules) ];
        _module.args = {
          inputs = inputs // {
            inherit yen;
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
    colmena.url = "github:zhaofengli/colmena";
    den.url = "github:denful/den";
    deploy-rs.url = "github:serokell/deploy-rs";
    impermanence.url = "github:nix-community/impermanence";
    microvm.url = "github:microvm-nix/microvm.nix";
    nix-on-droid.url = "github:nix-community/nix-on-droid";
    nixos-facter-modules.url = "github:numtide/nixos-facter-modules";
    terranix.url = "github:terranix/terranix";
    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    files.url = "github:sini/files";
    flake-file.url = "github:denful/flake-file";
    nixpkgs-unstable.url = "https://nixos.org/channels/nixos-unstable/nixexprs.tar.xz";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    import-tree.url = "github:denful/import-tree";
    fastest = {
      url = "github:denful/fastest"; # the parallel test runner: every suite is tests.<suite>.<test> = { expr; expected; } (its own nixpkgs: it builds there)
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "https://nixos.org/channels/nixos-25.05/nixexprs.tar.xz";
  };
}
