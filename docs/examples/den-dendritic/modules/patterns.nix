# Five of the dendritic aspect patterns, in yen. Each one is an aspect; only its `at` differs.
{ yen, ... }:
let
  inherit (yen.lib) all not;
in
{
  # Simple aspect: one feature, for every host.
  yen.aspects.basic-packages = {
    at = yen.kinds.host;
    nixos =
      { pkgs, ... }:
      {
        environment.systemPackages = [ pkgs.git ];
      };
  };

  # Inheritance aspect: system-desktop extends system-cli. system-cli applies wherever system-desktop does.
  # There is no `imports`, so a parent included by two children is still given once.
  yen.aspects.system-cli = {
    at = [
      yen.host.srv
      yen.aspects.system-desktop
      yen.aspects.system-dev
    ];
    nixos =
      { pkgs, ... }:
      {
        environment.systemPackages = [ pkgs.tmux ];
      };
  };
  yen.aspects.system-desktop = {
    at = yen.host.desk;
    nixos.services.printing.enable = true;
  };
  yen.aspects.system-dev = {
    at = yen.host.desk; # a second child on the same host: system-cli still comes once
    nixos.virtualisation.docker.enable = true;
  };

  # Conditional aspect: no lib.mkIf inside a module. `at` tests a fact, and can exclude.
  yen.aspects.nvidia = {
    at = s: (s.gpu or null) == "nvidia";
    nixos.services.xserver.videoDrivers = [ "nvidia" ];
  };
  yen.aspects.headless = {
    at = all [
      yen.kinds.host
      (not yen.aspects.system-desktop)
    ];
    nixos.documentation.enable = false;
  };

  # Constants aspect: a field of the fleet, read as the `fleet` arg. No options, no generic class.
  yen.aspects.acme = {
    at = yen.kinds.host;
    nixos =
      { fleet, ... }:
      {
        security.acme.defaults.email = fleet.adminEmail;
      };
  };

  # Factory aspect: `user "bob" true` becomes an instance with a field. The kind is the factory.
  yen.aspects.user-account = {
    at = yen.kinds.user;
    nixos =
      { user, ... }:
      {
        users.users.${user.name} = {
          isNormalUser = true;
          extraGroups = if user.admin then [ "wheel" ] else [ ];
        };
      };
  };
}
