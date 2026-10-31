# a name where a ref goes: the layout is a string
{ yen, ... }:
{
  yen.assembly.disk-bad = {
    kit = yen.kit.disko;
    roles.default = {
      at = yen.host.web;
      settings = {
        device = "/dev/sda";
        layout = "single-ext4";
      };
    };
  };
}
