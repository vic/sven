# a markdown table: `head` is a list of column titles, `rows` a list of lists of cell texts.
#   docs.table [ "Kind" "Scopes" ] [ [ "host" "3" ] ]
head: rows:
let
  b = builtins;
  row = cells: "| ${b.concatStringsSep " | " cells} |";
in
b.concatStringsSep "\n" (
  [
    (row head)
    "|${b.concatStringsSep "" (map (_: "---|") head)}"
  ]
  ++ map row rows
)
