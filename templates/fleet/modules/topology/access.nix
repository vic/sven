# Groups are data: nothing spawns them, so they have no scopes. Groups nest through `members`.
# A label partitions groups: posix groups make unix accounts, oauth groups only make SSO identities (sini ACL).
# A machine adds its own grants, and gates (when set) narrow who comes in.
{ yen, ... }:
let
  inherit (yen.lib) opt;
  groups = opt (yen.helpers.listOf yen.kinds.group) [ ];
in
{
  yen.kinds.group.fields = {
    members = groups;
    label = opt (yen.helpers.enum [
      "posix"
      "oauth"
    ]) "posix";
  };
  yen.kinds.machine.fields = {
    grants = groups;
    gates = groups;
  };
  yen.group = {
    ops = { };
    deploy = { };
    admin.members = [ yen.group.ops ];
    sso.label = "oauth";
  };
}
