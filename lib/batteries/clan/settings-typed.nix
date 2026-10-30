# at a member scope (from clan.members), the value of an `errors` key: each setting of its role's interface must be
# set and pass the option's type.
#   yen.aspects.settings-typed = { at = yen.kinds.member; errors = clan.settings-typed { inherit services; }; };
{ services }:
{ scope, ... }:
let
  b = builtins;
  iface = services.${scope.service}.roles.${scope.role}.interface or { };
in
b.concatMap (
  k:
  let
    o = iface.${k};
    v = scope.settings.${k};
  in
  if v == null || !o.type.check v then
    [ "clan: ${scope.instance}.${scope.role}: setting ${k} is not a ${o.type.description}" ]
  else
    [ ]
) (b.attrNames iface)
