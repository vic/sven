# clan's inventory: the value of a machine kind's `spawns.<member kind>`. One member per (instance, role) that the
# machine takes part in, by name or by tag. A member carries instance, service, role, its layered settings and the
# role's extraModules, so an aspect at the member kind runs once per instance (clan perInstance).
#   yen.kinds.host.spawns.member = clan.members { inherit instances services; labelsOf = m: [ "all" ] ++ m.labels; };
{
  instances,
  services,
  labelsOf ? m: m.labels or [ ],
}:
m:
let
  b = builtins;
  inherit (import ./_roles.nix) roleHas settingsOf;
in
b.listToAttrs (
  b.concatMap (
    n:
    let
      i = instances.${n};
    in
    b.concatMap (
      r:
      if roleHas labelsOf i.roles.${r} m then
        [
          {
            name = "${n}.${r}";
            value = {
              instance = n;
              service = i.module;
              role = r;
              settings = settingsOf services i r m;
              extraModules = i.roles.${r}.extraModules or [ ];
            };
          }
        ]
      else
        [ ]
    ) (b.attrNames i.roles)
  ) (b.attrNames instances)
)
