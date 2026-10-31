{
  description = "yen: deploy and infrastructure batteries";

  outputs =
    inputs:
    inputs.yen.lib.mkFlake {
      inherit inputs;
      inherit (inputs.nixpkgs) lib;
    } (inputs.import-tree ./modules);

  inputs = {
    yen.url = "github:vic/yen";
    import-tree.url = "github:denful/import-tree";
    nixpkgs.url = "https://nixos.org/channels/nixos-25.05/nixexprs.tar.xz";
    colmena.url = "github:zhaofengli/colmena";
    deploy-rs.url = "github:serokell/deploy-rs";
    terranix.url = "github:terranix/terranix";
  };
}
