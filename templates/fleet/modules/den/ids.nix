# Den: deterministic ids from sorted names (no state). Each host gets its own ssh port.
{ yen, ... }:
{
  yen.aspects.ssh-port = {
    at = yen.kinds.host;
    nixos =
      { host, ... }:
      {
        services.openssh.enable = true;
        services.openssh.ports = [ (2200 + yen.helpers.ids.${host.name}) ];
      };
  };
}
