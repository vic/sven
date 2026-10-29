# ci is a guest on stage, built with the stable channel while stage uses edge.
{ yen, ... }:
{
  yen.guest.ci = {
    environment = yen.environment.staging;
    channel = yen.channel.stable;
    system = yen.system.x86_64-linux;
    addr = "10.0.2.20";
    on = yen.host.stage;
  };
}
