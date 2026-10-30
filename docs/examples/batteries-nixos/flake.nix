{
  description = "yen: NixOS batteries";

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
    impermanence.url = "github:nix-community/impermanence";
    nixos-facter-modules.url = "github:numtide/nixos-facter-modules";
  };
}
