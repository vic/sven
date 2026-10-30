# assemblies of kits: the value of a machine kind's `spawns.<member kind>`. One member per (assembly, role) whose
# `at` holds at the machine. A member carries refs to its assembly and kit, the role and its layered settings, so an
# aspect at the member kind runs once per assembly and role.
#   yen.kinds.host.spawns.member = kits.members { assemblies = attrValues yen.assembly; inherit (yen.lib) holds; };
{
  assemblies,
  holds,
}:
m:
let
  b = builtins;
  inherit (import ./_roles.nix) takes settingsOf;
in
b.listToAttrs (
  b.concatMap (
    a:
    b.concatMap (
      r:
      if takes holds a.roles.${r} m then
        [
          {
            name = "${a.name}.${r}";
            value = {
              assembly = a;
              inherit (a) kit;
              role = r;
              settings = settingsOf a r m;
            };
          }
        ]
      else
        [ ]
    ) (b.attrNames a.roles)
  ) assemblies
)
