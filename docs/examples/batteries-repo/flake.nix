{
  description = "yen: repo batteries";

  outputs =
    inputs:
    inputs.yen.lib.mkFlake {
      imports = [ (inputs.import-tree ./modules) ];
      _module.args = {
        inherit inputs;
        inherit (inputs.nixpkgs) lib;
      };
    };

  inputs = {
    yen.url = "github:vic/yen";
    import-tree.url = "github:denful/import-tree";
    nixpkgs.url = "https://nixos.org/channels/nixos-25.05/nixexprs.tar.xz";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    files.url = "github:sini/files";
    flake-file.url = "github:denful/flake-file";
  };
}
