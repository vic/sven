{
  title = "Guests inside hosts";
  description = "Containers or VMs as scopes under their host. A guest's NixOS goes into the host, never the other way.";
  section = "recipes";
  order = 4;

  body =
    { docs, r, ... }:
    [
      ''
        A guest is a machine that runs inside a host: a NixOS container here, a microvm in the
        [reference fleet](https://github.com/vic/yen/blob/main/templates/fleet/modules/platforms/microvm.nix).
        It is a scope under its host, with its own `nixos` sink. That sink forwards its modules up, into the host.
      ''
      (docs.fileWith "{16-18}" "modules/kinds.nix")
      (docs.file "modules/machines.nix")
      (docs.file "modules/services.nix")
      (docs.routes r)
      ''
        `nginx` runs in the `web` container. The host `box` does not get it: the element went to `web`'s own sink.
      ''
      (docs.caution "Content flows up only" ''
        A host aspect never reaches its guests. To give every guest something, write an aspect with `at = yen.kinds.guest`,
        or `within` a host.
      '')
      (docs.sh "sudo nixos-rebuild switch --flake .#box   # builds box and both containers")
    ];

  checks =
    { r, ... }:
    {
      nginx-at-guest =
        r.active.nginx."fleet:main/host:box/guest:web" && !r.active.nginx."fleet:main/host:box";
    };
  e2e =
    { flake, ... }:
    let
      c = flake.nixosConfigurations.box.config;
    in
    {
      web = c.containers.web.config.services.nginx.enable;
      db = c.containers.db.config.services.postgresql.enable;
      host-clean = !c.services.nginx.enable;
    };
}
