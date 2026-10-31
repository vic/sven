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
            labels
            tags
            ;
          channel = host.settings.kernel.channel;
        };
      };
  };
}
