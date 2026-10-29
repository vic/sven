# A user: an account on each of her hosts, and her home.
{ yen, ... }:
{
  yen.user.alice.hosts = [
    yen.host.web
    yen.host.desk
  ];
  yen.aspects.alice = {
    at = yen.user.alice;
    nixos =
      { user, ... }:
      {
        users.users.${user.name} = {
          isNormalUser = true;
          extraGroups = [ "wheel" ];
        };
      };
    homeManager = {
      programs.git = {
        enable = true;
        userName = "Alice";
      };
      home.stateVersion = "25.05";
    };
  };
}
