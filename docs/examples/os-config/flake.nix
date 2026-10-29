{
  description = "sven: osConfig in home-manager modules";

  outputs =
    inputs:
    (import inputs.sven).lib.mkFlake {
      imports = [ (inputs.import-tree ./modules) ];
      _module.args = {
        inherit inputs;
        inherit (inputs.nixpkgs) lib;
      };
    };

  inputs = {
    sven = {
      url = "github:vic/sven";
      flake = false;
    };
    import-tree.url = "github:denful/import-tree";
    nixpkgs.url = "https://nixos.org/channels/nixos-25.05/nixexprs.tar.xz";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
