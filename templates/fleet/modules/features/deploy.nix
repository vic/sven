# deploy is `one` per host; tags are a set; vars are generated-value plans, never values.
{ yen, ... }:
{
  yen.aspects.deploy-record = {
    at = yen.kinds.host;
    deploy =
      { host, ... }:
      {
        address = host.addr;
        user = "deploy";
        inherit (host) buildHost;
      };
    vars =
      { host, ... }:
      {
        per-machine.${host.name}.deploy-key.files = [
          "key"
          "key.pub"
        ];
      };
  };
  yen.aspects.ca = {
    at = yen.fleet.main;
    vars.shared.ca.files = [
      "ca.crt"
      "ca.key"
    ];
  };
}
