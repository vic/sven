{
  title = "Deploy and infrastructure batteries";
  description = "colmena and deploy-rs, terranix, Kubernetes manifests, machines writing config into each other, modules exported for other flakes.";
  section = "batteries";
  route = "batteries/deploy";
  order = 8;

  body =
    { docs, result, ... }:
    [
      ''
        | Battery | Value of | Gives |
        |---|---|---|
        | `deploy.colmena { from; makeHive; meta; }` | `out` of a merge sink of `{ <host> = module; }` | `colmenaHive` |
        | `deploy.deploy-rs { configurations; hostname; activate; sshUser; }` | a function, in `yen.flake` | `deploy.nodes` from built configs |
        | `terranix.configuration { from; terranixConfiguration; system; name; }` | `out` of a terraform module sink | `terraformConfigurations.<name>` |
        | `k8s.manifests { from; lib; output; }` | `out` of a sink of manifest modules | `k8sManifests.<scope name>`, merged with the module system |
        | `distributed.nodes { from; }` | a NixOS key | the modules other machines wrote for this one |
        | `exports.modules { from; output; }` | `out` of a module sink at an export scope | `<output>.<scope name>` for other flakes |
      ''
      (docs.file "modules/fleet.nix")
      (docs.file "modules/machines.nix")
      ''
        Two aspects wrote the ingress of `axon`; the module system merged them:
      ''
      (docs.value result.flake.k8sManifests)
    ];

  checks =
    { result, ... }:
    {
      outputs =
        builtins.attrNames result.flake == [
          "colmenaHive"
          "deploy"
          "k8sManifests"
          "nixosConfigurations"
          "nixosModules"
          "terraformConfigurations"
        ];
      k8s =
        result.flake.k8sManifests.axon.ingress.web == {
          host = "web.example.org";
          port = 80;
          tls = true;
        };
      exports = builtins.length result.flake.nixosModules.base.imports == 1;
      deploy-rs =
        builtins.mapAttrs (_: n: n.hostname) result.flake.deploy.nodes == {
          lb = "10.0.0.1";
          web = "10.0.0.2";
        };
    };

  e2e =
    { flake, ... }:
    {
      colmena =
        builtins.attrNames flake.colmenaHive.nodes == [
          "lb"
          "web"
        ];
      deploy-rs = builtins.isString flake.deploy.nodes.web.profiles.system.path.drvPath;
      terranix = builtins.isString flake.terraformConfigurations.dns.drvPath;
      nodes =
        flake.nixosConfigurations.web.config.networking.extraHosts == "10.0.0.1 lb.internal\n"
        && flake.nixosConfigurations.lb.config.networking.extraHosts == "";
    };
}
