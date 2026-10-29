# The machine and its people: data, not configuration.
{ yen, ... }:
{
  yen.host.laptop = { };
  yen.user.alice = {
    hosts = [ yen.host.laptop ];
    groups = [ "wheel" ];
  };
}
