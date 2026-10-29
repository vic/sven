# den.batteries.define-user: an aspect. Who includes it is its `at`, from any file.
{ yen, ... }:
{
  yen.aspects.define-user = {
    nixos =
      { user, ... }:
      {
        users.users.${user.name} = {
          name = user.name;
          home = "/home/${user.name}";
          isNormalUser = true;
        };
      };
    homeManager =
      { user, ... }:
      {
        home.username = user.name;
        home.homeDirectory = "/home/${user.name}";
      };
  };
}
