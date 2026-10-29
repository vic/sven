# The tux aspect. `includes` becomes `at` on the included aspects.
{ yen, ... }:
{
  yen.user.tux.hosts = [ yen.host.igloo ];
  yen.aspects.define-user.at = yen.user.tux;
  yen.aspects.primary-user.at = yen.user.tux;
  yen.aspects.tux = {
    at = yen.user.tux;
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.htop ];
      };
  };
}
