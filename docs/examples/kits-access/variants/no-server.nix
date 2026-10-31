# an sshd assembly with no server: a count of zero, and a client with no server in its assembly
{ yen, ... }:
{
  yen.assembly = {
    none = {
      kit = yen.kit.sshd;
      roles.server.at = _: false;
    };
    alone = {
      kit = yen.kit.sshd;
      roles.client = {
        at = yen.machine.web;
        settings.root = ../vars/per-machine;
      };
    };
  };
}
