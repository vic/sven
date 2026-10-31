{
  description = "yen: platform batteries";

  outputs =
    inputs:
    inputs.yen.lib.mkFlake {
      imports = [ (inputs.import-tree ./modules) ];
      inherit inputs;
      inherit (inputs.nixpkgs) lib;
      yen.sinks = {
        inputs = { };
        lib = { };
      };
    };

  inputs = {
    yen.url = "github:vic/yen";
    import-tree.url = "github:denful/import-tree";
    nixpkgs.url = "https://nixos.org/channels/nixos-25.05/nixexprs.tar.xz";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    microvm.url = "github:microvm-nix/microvm.nix";
    nix-on-droid.url = "github:nix-community/nix-on-droid";
  };
}
