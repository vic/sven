# Generated from the `inputs` sink. Edit modules/, then run: nix run .#write-files
{
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
    files = {
      url = "github:sini/files";
    };
    import-tree = {
      url = "github:denful/import-tree";
    };
    nixpkgs = {
      url = "https://nixos.org/channels/nixos-25.05/nixexprs.tar.xz";
    };
    sven = {
      url = "github:vic/sven";
    };
  };
}
