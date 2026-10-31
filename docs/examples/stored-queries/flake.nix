{
  description = "yen: stored queries";

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
  };
}
