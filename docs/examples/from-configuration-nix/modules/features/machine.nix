# What every host gets: its generated hardware file, its name, and the boot and locale basics.
{ yen, ... }:
{
  yen.aspects.machine = {
    at = yen.kinds.host;
    nixos =
      { host, ... }:
      {
        imports = [ (../../machines + "/${host.name}/hardware-configuration.nix") ];
        networking.hostName = host.name;
        boot.loader.systemd-boot.enable = true;
        time.timeZone = "Europe/Berlin";
        i18n.defaultLocale = "en_US.UTF-8";
        nix.settings.experimental-features = [
          "nix-command"
          "flakes"
        ];
        system.stateVersion = "25.05";
      };
  };
}
