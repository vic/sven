# ana has a NixOS desktop, and a work laptop with another Linux: there she has home-manager only.
{ yen, ... }:
{
  yen.host.desk = { };
  yen.user.ana.hosts = [ yen.host.desk ];
  yen.home."ana@work" = {
    user = yen.user.ana;
    system = "x86_64-linux";
  };

  yen.aspects.desk = {
    at = yen.host.desk;
    nixos = {
      networking.hostName = "desk";
      boot.loader.grub.device = "nodev";
      fileSystems."/" = {
        device = "/dev/sda1";
        fsType = "ext4";
      };
      nixpkgs.hostPlatform = "x86_64-linux";
      system.stateVersion = "25.05";
      users.users.ana.isNormalUser = true;
    };
  };
  yen.aspects.home-base = {
    at = [
      yen.kinds.user
      yen.kinds.home
    ];
    homeManager.home.stateVersion = "25.05";
  };
  yen.aspects.standalone = {
    at = yen.kinds.home;
    homeManager =
      { home, ... }:
      {
        home.username = home.user.name;
        home.homeDirectory = "/home/${home.user.name}";
      };
  };
}
