# A second, different value for one declared leaf. NixOS: mkForce wins. yen: two answers.
{ yen, ... }:
{
  yen.host.a.addr = "10.0.0.9";
}
