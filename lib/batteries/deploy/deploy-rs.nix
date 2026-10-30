# deploy-rs nodes from built NixOS configurations (for example `out.nixosConfigurations` in `yen.flake`):
# `hostname` and `activate` read a configuration's name and value.
#   yen.flake = { out, ... }: out // deploy.deploy-rs { configurations = out.nixosConfigurations;
#     hostname = n: _: "${n}.lan"; activate = _: c: deploy-rs.lib.x86_64-linux.activate.nixos c; };
{
  configurations,
  hostname,
  activate,
  sshUser ? "root",
}:
{
  deploy.nodes = builtins.mapAttrs (n: c: {
    hostname = hostname n c;
    profiles.system = {
      user = "root";
      inherit sshUser;
      path = activate n c;
    };
  }) configurations;
}
