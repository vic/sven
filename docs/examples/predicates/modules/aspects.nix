{ yen, ... }:
let
  inherit (yen.lib)
    all
    not
    within
    has
    ;
in
{
  yen.aspects = {
    builder.at = s: (s.cores or 0) >= 16; # a function of the scope: a fact test
    cuda.at = all [
      yen.kinds.host
      (s: s.gpu)
    ]; # all of a list
    tiny.at = all [
      yen.kinds.host
      (not yen.aspects.builder)
    ]; # an aspect ref, negated
    vm-tools.at = within yen.aspects.cuda; # a proper ancestor holds
    vm-host.at = has yen.kinds.guest; # a child holds
    monitored.at = [
      yen.host.small
      yen.aspects.vm-host
    ]; # a list is "any"
  };
}
