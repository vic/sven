{ yen, ... }:
{
  yen.aspects.report = {
    at = yen.kinds.host;
    report =
      { host, ... }:
      {
        ${host.name} = {
          inherit (host)
            port
            jump
            vpn
            tags
            ;
          channel = host.settings.kernel.channel;
        };
      };
  };
}
