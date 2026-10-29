# A kind declares the fields of its instances. Every field has a type.
{ yen, lib, ... }:
{
  yen.kinds.host.fields = {
    addr = lib.types.str;
    cores = lib.types.int;
  };
}
