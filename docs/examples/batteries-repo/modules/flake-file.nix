# flake.nix written by github:vic/flake-file: each aspect declares the inputs it uses.
{
  yen,
  inputs,
  ...
}:
{
  yen.kinds.repo.sinks.flake-file = {
    reduce = yen.lib.reduce.merge;
    out = yen.lib.batteries.flake-file.write {
      from = yen.kinds.repo.sinks.flake-file;
      inherit (inputs.nixpkgs-unstable) lib; # flake-file needs the unstable lib
      inherit inputs;
      pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
    };
  };
  yen.aspects.flake = {
    at = yen.kinds.repo;
    flake-file = {
      description = "my repo";
      outputs = "inputs: import ./outputs.nix inputs";
      inputs.nixpkgs.url = "https://nixos.org/channels/nixos-25.05/nixexprs.tar.xz";
    };
  };
  yen.aspects.files-input = {
    at = yen.kinds.repo;
    flake-file.inputs.files.url = "github:sini/files";
  };
}
