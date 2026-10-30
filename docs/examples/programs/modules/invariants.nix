# Rules by reference: a rule is a function of its variables, and its literals come from `yen.facts`:
# `host.form H "server"` is "H is a host whose form is server". A rule with `bad = H` that holds is a violation.
{ yen, ... }:
let
  inherit (yen.facts) host has lt;
in
{
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

  # no two hosts share an address: a rule across machines (`lt` keeps one of each pair)
  yen.invariants.unique-addr =
    {
      A,
      B,
      X,
    }:
    {
      bad = [
        A
        B
      ];
      pos = [
        (host.addr A X)
        (host.addr B X)
        (lt A B)
      ];
    };
}
