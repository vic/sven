# den.default: an aspect at every scope of a kind.
{ yen, ... }:
{
  yen.aspects.state-version = {
    at = yen.kinds.host;
    nixos.system.stateVersion = "25.05";
  };
  yen.aspects.home-state-version = {
    at = yen.kinds.user;
    homeManager.home.stateVersion = "25.05";
  };
}
