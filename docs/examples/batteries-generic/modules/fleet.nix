# Your words: a fleet of hosts. Each host has an ssh key and an address. The batteries know none of these names.
{ yen, lib, ... }:
let
  str = lib.types.str;
in
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.host.fields = {
    sshKey = str;
    addr = str;
  };
  yen.fleet.main = { };
  yen.flake = { out, ... }: out;

  yen.host = {
    nas = {
      sshKey = "ssh-ed25519 AAAAnas";
      addr = "10.0.0.1";
    };
    desk = {
      sshKey = "ssh-ed25519 AAAAdesk";
      addr = "10.0.0.2";
    };
    laptop = {
      sshKey = "ssh-ed25519 AAAAlaptop";
      addr = "10.0.0.3";
    };
  };
}
