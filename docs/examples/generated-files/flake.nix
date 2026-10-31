# DO-NOT-EDIT. This file was auto-generated using github:denful/flake-file.
# Use `nix run .#write-flake` to regenerate it.
{
  description = "A fleet that writes its own flake.nix, README.md and CI workflow";

  outputs =
    inputs:
    inputs.yen.lib.mkFlake {
      inherit inputs;
      inherit (inputs.nixpkgs) lib;
    } (inputs.import-tree ./modules);

  inputs = {
    files.url = "github:sini/files";
    flake-file.url = "github:denful/flake-file";
    import-tree.url = "github:denful/import-tree";
    nixpkgs.url = "https://nixos.org/channels/nixos-25.05/nixexprs.tar.xz";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    yen.url = "github:vic/yen";
  };
}
