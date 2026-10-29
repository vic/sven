{ yen, lib, ... }:
{
  yen.host = lib.genAttrs [ "app-1" "app-2" "app-3" ] (_: {
    sharedPkgs = true;
  });
  yen.aspects.app = {
    at = yen.kinds.host;
    nixos =
      { host, pkgs, ... }:
      {
        networking.hostName = host.name;
        environment.systemPackages = [ pkgs.htop ];
        boot.loader.grub.device = "nodev";
        fileSystems."/" = {
          device = "/dev/sda1";
          fsType = "ext4";
        };
        system.stateVersion = "25.05";
      };
  };
  # docs differ when pkgs is shared: keep them off on sharing hosts
  yen.aspects.shared-no-docs = {
    at = yen.lib.all [
      yen.kinds.host
      (s: s.sharedPkgs)
    ];
    nixos.documentation = {
      enable = false;
      nixos.enable = false;
      man.enable = false;
    };
  };
}
