{ yen, ... }:
{
  yen.host.desk = { };
  yen.user.ana.hosts = [ yen.host.desk ];
  yen.user.bob.hosts = [ yen.host.desk ];
  yen.aspects.desk = {
    at = yen.host.desk;
    nixos = {
      boot.loader.grub.device = "nodev";
      fileSystems."/" = {
        device = "/dev/sda1";
        fsType = "ext4";
      };
      nixpkgs.hostPlatform = "x86_64-linux";
      system.stateVersion = "25.05";
    };
  };
  yen.aspects.gaming = {
    at = yen.host.desk;
    unfree = [
      "steam"
      "steam-unwrapped"
    ];
    nixos.programs.steam.enable = true;
  };
  yen.aspects.bob-tools = {
    at = yen.user.bob;
    unfree = [ "vscode" ];
    insecure = [ "olm-3.2.16" ];
  };
}
