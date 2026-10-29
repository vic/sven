{ yen, ... }:
{
  yen.aspects.ssh = {
    at = yen.kinds.host;
    nixos.services.openssh.enable = true;
  };
}
