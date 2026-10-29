# Per-system outputs, a VM check, and a check on a realized config (#60).
{ yen, inputs, ... }:
{
  yen.aspects.tools = {
    at = yen.kinds.system;
    packages =
      { system, ... }:
      {
        inherit (inputs.nixpkgs.legacyPackages.${system.name}) hello;
      };
  };
  yen.aspects.web-check = {
    at = yen.system.x86_64-linux;
    checks.web = {
      nodes.web = {
        services.nginx.enable = true;
        networking.firewall.allowedTCPPorts = [ 80 ];
      };
      nodes.client = { };
      testScript = ''
        start_all()
        web.wait_for_unit("nginx")
        client.wait_until_succeeds("curl -sf http://web/")
      '';
    };
  };
  yen.aspects.headless = {
    at = yen.system.x86_64-linux;
    no-gui.lb = [ "firefox" ];
  };
  yen.aspects.docs = {
    at = yen.kinds.fleet;
    out =
      { ... }:
      {
        docs.mermaid = yen.helpers.mermaid yen.lib.graph;
      };
  };
}
