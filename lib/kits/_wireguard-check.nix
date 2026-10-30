# the addresses and the error records of one wireguard assembly (kit wireguard): `es` are the reduced exports of the
# assembly; `pk` reads a public key or null. `check` lists address errors, members that disagree on the prefix and
# members whose public key file is missing.
{
  yen,
  lib,
  pk,
}:
let
  b = builtins;
  alloc =
    es:
    yen.lib.batteries.addresses {
      prefix = (b.head es).value.prefix; # the same in every member: a difference is an error (check)
      members = map (name: { inherit name; }) (lib.unique (map (x: x.machine.name) es));
    };
in
{
  inherit alloc;
  check =
    es:
    let
      p = b.head es;
      differ = b.any (x: x.value.prefix != p.value.prefix) es;
    in
    (alloc es).errors
    ++ (
      if differ then
        [ { error = "wireguard: assembly ${p.assembly.name} members disagree on prefix"; } ]
      else
        [ ]
    )
    ++ map (x: { error = "wireguard: ${x.machine.name} has no ${x.value.public} public key"; }) (
      b.filter (x: pk x == null) es
    );
}
