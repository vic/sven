# substitute: motd-short replaces motd on web-2 through `not`.
{ yen, ... }:
let
  inherit (yen.lib) all not;
in
{
  yen.aspects.motd = {
    at = all [
      yen.helpers.machines
      (not yen.aspects.motd-short)
    ];
    os.environment.etc.motd.text = "managed by yen";
  };
  yen.aspects.motd-short = {
    at = yen.host.web-2;
    os.environment.etc.motd.text = "yen";
  };
}
