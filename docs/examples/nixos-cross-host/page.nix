{
  title = "Facts from other hosts";
  description = "known_hosts, WireGuard peers and Syncthing devices built from the other hosts, without reading nixosConfigurations.";
  section = "nixos";
  route = "nixos/cross-host";
  order = 4;

  body =
    { docs, ... }:
    [
      ''
        Some configuration of a host is about the other hosts: SSH `knownHosts`, WireGuard peers, Syncthing devices,
        backup targets. The usual answers:

        - A hand-written list of hosts in a shared file. It goes out of date when you add a host.
        - `self.nixosConfigurations.<other>.config` through `specialArgs`. When two hosts read derived values from
          each other, the evaluation can recurse without end.
        - The *collector aspect* of the
          [dendritic design guide](https://github.com/Doc-Steve/dendritic-design-with-flake-parts/wiki/Dendritic_Aspects):
          each host feature adds its own device to a shared NixOS module. It works, but every host gets every
          contribution, its own included.

        In yen a host's public facts are fields of its instance. Every module can read `yen.host`: it is data, so
        nothing evaluates a NixOS system to read it.
      ''
      (docs.file "modules/fleet.nix")
      (docs.file "modules/mesh.nix")
      ''
        ## Facts that only some hosts have

        A Syncthing device id exists only on hosts that run Syncthing. Each of them gives its id to the
        `syncthing-device` sink of the fleet. A host has no such sink, so the id goes up to the fleet. A Syncthing
        host then reads the sink as an arg. `entries` keeps who gave each id, so a host can leave out its own.
      ''
      (docs.file "modules/syncthing.nix")
      (docs.note "Why there is no recursion" ''
        `yen.host` and the `syncthing-device` sink are yen data. They exist before any NixOS module runs. A NixOS
        module reads them, and never reads another host's NixOS `config`.
      '')
      (docs.tip "As a battery" ''
        This page writes the rule by hand. The shape is ready as `yen.lib.batteries.mesh`: the records of a sink, except
        your own. See [Generic batteries](/batteries/generic/). When it does not fit, keep your own copy of the lines above.
      '')
    ];

  checks =
    {
      result,
      eq,
      yes,
      no,
      ...
    }:
    {
      hosts = eq (builtins.attrNames result.flake.nixosConfigurations) ([
        "desk"
        "laptop"
        "nas"
      ]);
    };

  e2e =
    {
      flake,
      eq,
      yes,
      no,
      ...
    }:
    let
      c = n: flake.nixosConfigurations.${n}.config;
      peers = n: map (p: p.allowedIPs) (c n).networking.wireguard.interfaces.wg0.peers;
    in
    {
      known = eq (builtins.attrNames (c "desk").programs.ssh.knownHosts) ([
        "laptop"
        "nas"
      ]);
      peers = eq (peers "laptop") ([
        [ "10.9.0.2/32" ]
        [ "10.9.0.1/32" ]
      ]);
      syncthing = eq (builtins.attrNames (c "desk").services.syncthing.settings.devices) ([ "nas" ]);
      syncthing-nas = eq (builtins.attrNames (c "nas").services.syncthing.settings.devices) ([ "desk" ]);
      no-syncthing = no ((c "laptop").services.syncthing.enable);
    };
}
