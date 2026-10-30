{
  result,
  variant,
  eq,
  yes,
  no,
  ...
}:
let
  msgs = v: map (e: e.error) (variant v).errors;
in
{
  known-hosts = {
    t1 = eq (result.flake.nixos.web.programs.ssh.knownHosts.db.publicKey) (
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDocsKeyNotReal db"
    );
    t2 = no (result.flake.nixos.db ? programs);
  };
  server = {
    t1 = yes (result.flake.os.db.services.openssh.enable);
    t2 = no (result.flake.os ? web);
  };
  generators = eq (builtins.attrNames result.reduced.generators."fleet:main") ([
    "emergency-root@db"
    "openssh@db"
    "user-ops@web"
  ]);
  emergency = {
    t1 = eq (result.flake.nixos.db.users.users.root.openssh.authorizedKeys.keys) ([
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBreakGlassKeyNotReal admin"
    ]);
    t2 = no (result.flake.nixos.web.users.users ? root);
  };
  no-server = eq (msgs "variants/no-server.nix") ([
    "kits: assembly none role server: 0 machines, at least 1"
    "sshd: alone.client has no server in its assembly"
  ]);
  missing-key = eq (msgs "variants/missing-key.nix") ([
    "known-hosts: edge has no openssh/ssh.id_ed25519.pub public key"
  ]);
  same-user = eq (msgs "variants/same-user.nix") ([
    "users: ops is set by assemblies ops and ops-again on web"
  ]);
}
