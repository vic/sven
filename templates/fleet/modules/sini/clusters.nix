# Clusters under an environment. Discovery (den collect): k3s nodes reduce at the environment; the reader filters.
{ yen, lib, ... }:
let
  inherit (yen.lib) maybe same;
  inherit (yen.lib.reduce) entries;
  clusterOf = h: lib.findFirst (c: lib.any (same h) c.hosts) null (lib.attrValues yen.cluster);
  members = c: lib.filter (e: lib.any (same e.from) c.hosts);
in
{
  yen.kinds.environment.spawns.cluster = s: lib.filterAttrs (_: c: same c.environment s) yen.cluster;
  yen.kinds.cluster = {
    fields = {
      environment = yen.kinds.environment;
      hosts = yen.helpers.listOf yen.kinds.host;
      ingestUrl = maybe lib.types.str;
    };
    sinks.k8s-manifests.out =
      { cluster, k8s-manifests, ... }:
      {
        k8sManifests.${cluster.name} =
          (lib.evalModules {
            modules = [ { freeformType = lib.types.attrsOf lib.types.anything; } ] ++ k8s-manifests;
          }).config;
      };
  };
  yen.cluster.axon = {
    environment = yen.environment.prod;
    hosts = [
      yen.host.web-1
      yen.host.web-2
    ];
    ingestUrl = "https://ingest.example.org";
  };
  yen.aspects.axon = {
    at = yen.cluster.axon;
    k8s-manifests.target.branch = "main";
  };

  yen.kinds.environment.sinks.k3s-nodes.reduce = entries;
  yen.aspects.k3s = {
    at = s: clusterOf s != null;
    k3s-nodes = { host, ... }: host.addr;
    # The first node starts the cluster, the others join it. `at` puts the host among its cluster's nodes, so the list is never empty.
    nixos =
      { k3s-nodes, host, ... }:
      let
        first = lib.head (members (clusterOf host) k3s-nodes);
      in
      {
        services.k3s.enable = true;
      }
      // (
        if same first.from host then
          { services.k3s.clusterInit = true; }
        else
          { services.k3s.serverAddr = "https://${first.value}:6443"; }
      );
  };
  yen.aspects.k3s-registries = {
    at = yen.kinds.cluster;
    k8s-manifests =
      { cluster, k3s-nodes, ... }:
      {
        applications.k3s.nodes = map (e: e.value) (members cluster k3s-nodes);
      };
  };

  # Across environments: reduce at the fleet, filter by a ref field.
  yen.kinds.environment.fields.monitoring = maybe yen.kinds.cluster;
  yen.environment.prod.monitoring = yen.cluster.axon;
  yen.kinds.fleet.sinks.monitoring-ingest.reduce = entries;
  yen.aspects.ingest = {
    at = yen.lib.all [
      yen.kinds.cluster
      (s: s.ingestUrl != null)
    ];
    monitoring-ingest = { cluster, ... }: cluster.ingestUrl;
  };
  yen.aspects.alloy = {
    at = yen.helpers.linux;
    nixos =
      { monitoring-ingest, environment, ... }:
      {
        environment.etc."alloy/endpoints".text = lib.concatLines (
          map (e: e.value) (
            lib.filter (
              e: environment.monitoring != null && same e.from environment.monitoring
            ) monitoring-ingest
          )
        );
      };
  };
}
