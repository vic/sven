# Two servers and one rule. The desktop runs on `web`, so `web` breaks the rule and `db` does not.
{ yen, ... }:
let
  inherit (yen.facts) host has;
in
{
  yen.fleet.main = { };
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.host.fields.form = yen.lib.is (v: v == "server" || v == "laptop");
  yen.host.web.form = "server";
  yen.host.db.form = "server";
  yen.aspects.desktop.at = yen.host.web;

  # no server runs a desktop
  yen.invariants.no-desktop-on-servers =
    { H }:
    {
      bad = H;
      pos = [
        (host.form H "server")
        (has yen.aspects.desktop H)
      ];
    };
}
