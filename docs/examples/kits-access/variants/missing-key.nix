# a server whose public host key was never generated: there is no file under vars/per-machine/edge
{ yen, ... }:
{
  yen.machine.edge = { };
  yen.assembly.ssh-edge = {
    kit = yen.kit.sshd;
    roles = {
      server.at = yen.machine.edge;
      client = {
        at = yen.machine.web;
        settings.root = ../vars/per-machine;
      };
    };
  };
}
