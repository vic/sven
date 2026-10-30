{ yen, ... }:
let
  b = yen.lib.batteries;
in
{
  yen.aspects.machine = {
    at = [
      yen.kinds.host
      yen.export.base # the same base, exported for other flakes
    ];
    nixos = {
      boot.loader.grub.device = "nodev";
      fileSystems."/" = {
        device = "/dev/sda1";
        fsType = "ext4";
      };
      nixpkgs.hostPlatform = "x86_64-linux";
      system.stateVersion = "25.05";
    };
  };
  yen.aspects.hive = {
    at = yen.kinds.host;
    colmena =
      { host, ... }:
      {
        ${host.name} = {
          deployment.targetHost = host.addr;
          imports = [ { networking.hostName = host.name; } ];
        };
      };
    terraform =
      { host, ... }:
      {
        resource.cloudflare_record.${host.name} = {
          name = host.name;
          content = host.addr;
          type = "A";
        };
      };
    nixos = b.distributed.nodes { from = yen.kinds.fleet.sinks.nodes; };
  };
  # lb writes into web: its backends know the load balancer
  yen.aspects.lb-writes-web = {
    at = yen.host.lb;
    nodes =
      { host, ... }:
      {
        web.networking.extraHosts = "${host.addr} lb.internal";
      };
  };
  yen.aspects.ingress = {
    at = yen.cluster.axon;
    k8s.ingress.web = {
      host = "web.example.org";
      port = 80;
    };
  };
  yen.aspects.ingress-tls = {
    at = yen.cluster.axon;
    k8s.ingress.web.tls = true;
  };
}
