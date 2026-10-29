{ yen, ... }:
{
  yen.mac.studio = {
    environment = yen.environment.staging;
    channel = yen.channel.stable;
    system = yen.system.aarch64-darwin;
    addr = "10.0.2.30";
    system-owner = yen.user.alice;
  };
}
