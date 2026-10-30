# at a member scope (from clan.members): the role's extraModules, as one module for the machine's class sink.
#   yen.aspects.extra = { at = all [ yen.kinds.member (s: s.extraModules != [ ]) ]; os = clan.extra-modules; };
{ scope, ... }:
{
  imports = scope.extraModules;
}
