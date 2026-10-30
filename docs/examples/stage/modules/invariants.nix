# Rules over `result.facts`, as data. A fact is a list: [ "kind" K ID ], [ "has" ASPECT ID ], [ "val" FIELD ID VALUE ], …
# A variable is { var = "X"; }; every string is a constant. A true [ "bad" … ] atom is a violation.
{ ... }:
let
  v = x: { var = x; };
in
{
  # no server runs a desktop
  yen.invariants.no-desktop-on-servers = [
    {
      head = [
        "bad"
        "desktop-on-server"
        (v "H")
      ];
      pos = [
        [
          "val"
          "form"
          (v "H")
          "server"
        ]
        [
          "has"
          "desktop"
          (v "H")
        ]
      ];
    }
  ];
  # no two hosts share an address: a rule across machines (`lt` keeps one of each pair)
  yen.invariants.unique-addr = [
    {
      head = [
        "bad"
        "same-addr"
        (v "A")
        (v "B")
      ];
      pos = [
        [
          "kind"
          "host"
          (v "A")
        ]
        [
          "kind"
          "host"
          (v "B")
        ]
        [
          "val"
          "addr"
          (v "A")
          (v "X")
        ]
        [
          "val"
          "addr"
          (v "B")
          (v "X")
        ]
        [
          "lt"
          (v "A")
          (v "B")
        ]
      ];
    }
  ];
}
