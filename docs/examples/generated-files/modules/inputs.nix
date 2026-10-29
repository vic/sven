# Each feature declares the inputs it uses, next to the code that uses them.
{ sven, ... }:
{
  sven.aspects.core-inputs = {
    at = sven.kinds.fleet;
    inputs = {
      sven.url = "github:vic/sven";
      import-tree.url = "github:denful/import-tree";
      files.url = "github:sini/files";
    };
  };
  sven.aspects.web = {
    at = sven.host.web;
    inputs.nixpkgs.url = "https://nixos.org/channels/nixos-25.05/nixexprs.tar.xz"; # goes up to the fleet's `inputs` sink
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
