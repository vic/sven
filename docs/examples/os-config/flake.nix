{
  description = "yen: osConfig in home-manager modules";

  outputs =
    inputs:
    (import inputs.yen).lib.mkFlake {
      inherit inputs;
      inherit (inputs.nixpkgs) lib;
    } (inputs.import-tree ./modules);

  inputs = {
    yen = {
      url = "github:vic/yen";
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
