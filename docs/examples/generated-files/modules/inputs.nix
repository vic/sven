# Each feature declares the inputs it uses, next to the code that uses them.
{ sven, ... }:
{
  sven.aspects.core-inputs = {
    at = sven.kinds.fleet;
    flake-file = {
      description = "A fleet that writes its own flake.nix, README.md and CI workflow";
      outputs = ''
        inputs:
        inputs.sven.lib.mkFlake {
          imports = [ (inputs.import-tree ./modules) ];
          _module.args = {
            inherit inputs;
            inherit (inputs.nixpkgs) lib;
          };
        }
      '';
      inputs = {
        sven.url = "github:vic/sven";
        import-tree.url = "github:denful/import-tree";
        flake-file.url = "github:denful/flake-file";
        files.url = "github:sini/files";
        nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable"; # flake-file's lib
      };
    };
  };
  sven.aspects.web = {
    at = sven.host.web;
    flake-file.inputs.nixpkgs.url = "https://nixos.org/channels/nixos-25.05/nixexprs.tar.xz"; # goes up to the fleet's `flake-file` sink
    nixos = {
      services.nginx.enable = true;
      boot.loader.grub.device = "nodev";
      fileSystems."/" = {
        device = "/dev/sda1";
        fsType = "ext4";
      };
      nixpkgs.hostPlatform = "x86_64-linux";
      system.stateVersion = "25.05";
    };
  };
}
