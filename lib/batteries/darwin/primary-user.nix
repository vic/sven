#: lib.batteries.darwin.primary-user :: { user; } -> key value -- system.primaryUser from the user that user reads (null: root)
# system.primaryUser (the user that user-level options such as the dock apply to): `user` reads a ref or a name
# from the scope; null falls back to root.
#   darwin = darwin.primary-user { user = m: m.system-owner; };
{ user }:
{ scope, ... }:
let
  u = user scope;
in
{
  system.primaryUser =
    if u == null then
      "root"
    else if builtins.isAttrs u then
      u.name
    else
      u;
}
