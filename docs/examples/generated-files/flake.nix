# DO-NOT-EDIT. This file was auto-generated using github:denful/flake-file.
# Use `nix run .#write-flake` to regenerate it.
{
  description = "A fleet that writes its own flake.nix, README.md and CI workflow";

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
    files.url = "github:sini/files";
    flake-file.url = "github:denful/flake-file";
    import-tree.url = "github:denful/import-tree";
    nixpkgs.url = "https://nixos.org/channels/nixos-25.05/nixexprs.tar.xz";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    sven.url = "github:vic/sven";
  };
}
