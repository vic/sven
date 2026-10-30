# Hosts and a cluster in one environment. Hosts build NixOS and join a colmena hive; deploy-rs reads the built configs.
{
  yen,
  lib,
  inputs,
  ...
}:
let
  b = yen.lib.batteries;
in
{
  yen.kinds.fleet = {
    spawns = {
      host = _: yen.host;
      cluster = _: yen.cluster;
      export = _: yen.export;
    };
    sinks = {
      out.reduce = yen.lib.reduce.merge;
      # each host gives its own NixOS modules to the hive
      colmena = {
        reduce = yen.lib.reduce.merge;
        out = b.deploy.colmena {
          from = yen.kinds.fleet.sinks.colmena;
          inherit (inputs.colmena.lib) makeHive;
          meta.nixpkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
        };
      };
      # dns records as terraform, built with terranix
      terraform.out = b.terranix.configuration {
        from = yen.kinds.fleet.sinks.terraform;
        inherit (inputs.terranix.lib) terranixConfiguration;
        system = "x86_64-linux";
        name = _: "dns";
      };
      # machines write NixOS config into each other (oddlama's nodes.<name>)
      nodes.reduce = yen.lib.reduce.entries;
    };
  };
  yen.kinds.host = {
    fields.addr = lib.types.str;
    sinks.nixos.out = b.nixos.system {
      from = yen.kinds.host.sinks.nixos;
      inherit (inputs) nixpkgs;
    };
  };
  yen.kinds.cluster.sinks.k8s.out = b.k8s.manifests {
    from = yen.kinds.cluster.sinks.k8s;
    inherit lib;
  };
  # an export never builds a machine: what lands on it is nixosModules.<name> for other flakes
  yen.kinds.export.sinks.nixos.out = b.exports.modules {
    from = yen.kinds.export.sinks.nixos;
    output = "nixosModules";
  };

  yen.fleet.main = { };
  yen.host = {
    lb.addr = "10.0.0.1";
    web.addr = "10.0.0.2";
  };
  yen.cluster.axon = { };
  yen.export.base = { };
  # deploy-rs: one node per built NixOS config
  yen.flake =
    { out, ... }:
    out
    // b.deploy.deploy-rs {
      configurations = out.nixosConfigurations;
      hostname = n: _: yen.host.${n}.addr;
      activate = _: c: inputs.deploy-rs.lib.x86_64-linux.activate.nixos c;
    };
}
