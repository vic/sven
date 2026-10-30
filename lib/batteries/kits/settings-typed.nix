#: lib.batteries.kits.settings-typed :: { scope; } -> [ error ] -- each setting of the member role is set and passes its type
# at a member scope (from kits.members), the value of an `errors` key: each setting of its role's interface must be
# set and pass the option's type.
#   yen.aspects.settings-typed = { at = yen.kinds.member; errors = kits.settings-typed; };
{ scope, ... }:
let
  b = builtins;
  iface = scope.kit.roles.${scope.role}.interface or { };
in
b.concatMap (
  k:
  let
    o = iface.${k};
    v = scope.settings.${k};
  in
  if v == null || !o.type.check v then
    [ "kits: ${scope.assembly.name}.${scope.role}: setting ${k} is not a ${o.type.description}" ]
  else
    [ ]
) (b.attrNames iface)
