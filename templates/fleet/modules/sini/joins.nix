# sini joins and data-shaped aspects: two pools joined by host, a guest's intent read by its parent,
# aspect factories, an aspect checked alone with stand-in arguments, and one edge environment at most.
{
  yen,
  lib,
  inputs,
  ...
}:
let
  inherit (yen.lib) all opt same;
  inherit (yen.lib.reduce) entries;
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
  by = from: lib.filter (e: same e.from from);
  # a factory: an aspect with instance data (sini `dns.cloudflare "json64"`)
  cloudflare = account: at: {
    inherit at;
    dns-zones =
      { domain, ... }:
      {
        inherit account;
        zone = domain.name;
      };
  };
in
{
  # served-domains ⋈ gateway-upstreams by host, in the cluster's environment; `exclude` drops names.
  yen.kinds.fleet.sinks = {
    served-domains.reduce = entries;
    gateway-upstreams.reduce = entries;
    dns-zones.reduce = yen.lib.reduce.list;
  };
  yen.aspects.served = {
    at = [
      yen.host.web-1
      yen.host.web-2
    ];
    served-domains =
      { host, ... }:
      [
        "${host.name}.example.org"
        "admin.${host.name}.example.org"
      ];
  };
  yen.aspects.gateway-upstream = {
    at = yen.host.web-1;
    gateway-upstreams =
      { host, ... }:
      {
        address = host.addr;
        exclude = [ "admin.web-1.example.org" ];
      };
  };
  yen.aspects.host-upstreams = {
    at = yen.kinds.cluster;
    k8s-manifests =
      {
        cluster,
        served-domains,
        gateway-upstreams,
        ...
      }:
      {
        applications.gateway.listeners = lib.concatMap (
          u: lib.subtractLists u.value.exclude (lib.concatMap (d: d.value) (by u.from served-domains))
        ) (lib.filter (u: same u.from.environment cluster.environment) gateway-upstreams);
      };
  };

  # The guest states its passthrough devices; the parent host binds them to vfio.
  yen.kinds.guest.fields.passthrough = opt (yen.helpers.listOf lib.types.str) [ ];
  yen.guest.ci.passthrough = [ "10de:2203" ];
  yen.aspects.vfio = {
    at = all [
      yen.kinds.host
      (s: lib.any (g: same g.on s && g.passthrough != [ ]) (lib.attrValues yen.guest))
    ];
    cycle =
      { tree, ... }:
      let
        guests.children = yen.kinds.guest; # a tree request: the guests this host spawns
      in
      {
        tree = [ guests ];
        nixos.environment.etc."vfio/ids".text = lib.concatStringsSep "," (
          lib.concatMap (g: g.passthrough) (lib.head (tree.select guests))
        );
      };
  };

  # Factories: one function, two instances.
  yen.aspects.cloudflare-json64 = cloudflare "json64" yen.domain."example.org";
  yen.aspects.cloudflare-api = cloudflare "api" yen.domain."api.example.org";

  # The aspect is a value: a check applies it to a stand-in cluster with the flag forced on, whatever axon sets.
  yen.kinds.cluster.fields.settings.guard.enable = opt lib.types.bool false;
  yen.cluster.axon.settings.guard.enable = true;
  yen.kinds.fleet.sinks.unit-checks = {
    reduce = yen.lib.reduce.merge;
    out =
      { unit-checks, ... }:
      {
        checks.x86_64-linux = lib.mapAttrs (
          n: ok: pkgs.runCommand n { } (if ok then "touch $out" else "echo ${n}: failed; exit 1")
        ) unit-checks;
      };
  };
  yen.aspects.guard-pod = {
    at = yen.kinds.fleet;
    cycle =
      { tree, ... }:
      let
        lb.scopesOf = yen.host.lb; # the same request as guard asks: the same answer
        run = yen.helpers.guard {
          scope.settings.guard.enable = true;
          inherit tree;
        };
      in
      {
        tree = [ lb ];
        unit-checks = [
          { guard-pod = (lib.head run.k8s-manifests).applications.guard.hub == "alice@lb"; }
        ];
      };
  };

  # At most one environment is the DNS edge.
  yen.aspects.one-edge = {
    at = yen.kinds.fleet;
    cycle =
      { tree, ... }:
      let
        envs.instances = yen.kinds.environment; # a tree request: every environment, with its data
        n = lib.length (lib.filter (e: e.dns.publicIPv4 != null) (lib.head (tree.select envs)));
      in
      {
        tree = [ envs ];
        errors = [
          (lib.optional (n > 1) "dns: ${toString n} environments set dns.publicIPv4, at most one may")
        ];
      };
  };
}
