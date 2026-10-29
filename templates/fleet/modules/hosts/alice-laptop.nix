# A standalone home: alice on the edge channel, no machine above.
{ yen, ... }:
{
  yen.home.alice-laptop = {
    user = yen.user.alice;
    channel = yen.channel.edge;
    system = yen.system.x86_64-linux;
  };
}
