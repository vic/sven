# sini services: SSO identities per environment, a provider allow-list joined from fleet pools,
# and a cluster aspect that reads a named host.
{ yen, lib, ... }:
let
  inherit (yen.lib) all opt;
  inherit (yen.lib.reduce) entries;
  named = n: lib.filter (e: e.value.name == n);
in
{
  # Users whose oauth groups meet the environment's grants: identities only, no unix account (helpers.usersOn).
  yen.kinds.environment.sinks.idm-users.reduce = yen.lib.reduce.one;
  yen.aspects.idm = {
    at = yen.kinds.environment;
    idm-users =
      { environment, ... }:
      lib.attrNames (
        lib.filterAttrs (
          _: u:
          yen.helpers.meets (lib.filter (g: g.label == "oauth") (
            yen.helpers.closure u.groups
          )) environment.grants
        ) yen.user
      );
  };

  # ninfer: the provider admits named hosts (by the fleet address pool) and every host whose aspects include the client.
  # A named host with no address is an error, not a silent gap.
  yen.kinds.machine.fields.settings.inference.clients = opt (yen.helpers.listOf lib.types.str) [ ];
  yen.host.lb.settings.inference.clients = [ "web-1" ];
  yen.kinds.fleet.sinks = {
    host-addrs.reduce = entries;
    inference-clients.reduce = entries;
  };
  yen.aspects.host-addrs = {
    at = yen.kinds.host;
    host-addrs =
      { host, ... }:
      {
        inherit (host) name addr;
      };
  };
  yen.aspects.inference-client = {
    at = yen.aspects.role-workstation;
    inference-clients = { host, ... }: host.addr;
  };
  yen.aspects.inference = {
    at = all [
      yen.kinds.host
      (s: s.settings.inference.clients != [ ])
    ];
    nixos =
      {
        host,
        host-addrs,
        inference-clients,
        ...
      }:
      {
        environment.etc."inference/allow".text = lib.concatLines (
          lib.unique (
            lib.concatMap (n: map (e: e.value.addr) (named n host-addrs)) host.settings.inference.clients
            ++ map (e: e.value) inference-clients
          )
        );
      };
    errors =
      { host, host-addrs, ... }:
      map (n: "inference: client ${n} has no address") (
        lib.filter (n: named n host-addrs == [ ]) host.settings.inference.clients
      );
  };

  # A cluster aspect reads a named host directly: the hub is lb's system owner.
  yen.aspects.guard = {
    at = yen.cluster.axon;
    k8s-manifests =
      { cluster, ... }:
      lib.optionalAttrs cluster.settings.guard.enable {
        applications.guard.hub = "${yen.host.lb.system-owner.name}@lb";
      };
  };
}
