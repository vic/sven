# Two aspects that each hold where the other does not: no answer.
{ yen, ... }:
{
  yen.aspects.left.at = yen.lib.all [
    yen.kinds.host
    (yen.lib.not yen.aspects.right)
  ];
  yen.aspects.right.at = yen.lib.all [
    yen.kinds.host
    (yen.lib.not yen.aspects.left)
  ];
  yen.aspects.typo.at = "host";
}
