# access kits: who may log in and how machines trust each other. sshd, users and emergency-access come from yen.lib.kits;
# this file is the fleet's assemblies of them. Public host keys are read from vars/per-machine.
{ yen, inputs, ... }:
let
  inherit (yen) kit host;
in
{
  imports = [ inputs.yen.lib.kits.emergency-access ];

  yen.assembly = {
    # lb serves, web-1 trusts the host keys of this assembly's servers (the `sshd` assembly has no client)
    ssh-trust = {
      kit = kit.sshd;
      roles = {
        server.at = host.lb;
        client = {
          at = host.web-1;
          settings.root = ../../vars/per-machine;
        };
      };
    };
    ops = {
      kit = kit.users;
      roles.default = {
        at = host.web-1;
        settings = {
          user = "ops";
          groups = [ "wheel" ];
        };
      };
    };
    emergency = {
      kit = kit.emergency-access;
      roles.default = {
        at = host.lb;
        settings.authorizedKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBreakGlassKeyNotReal admin" ];
      };
    };
  };
}
