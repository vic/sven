# Fleet oracles: one check per row of Ren's expected-results table, sini's patterns and Den's.
# Run (in parallel): nix run github:denful/fastest#fastest -- --flake "$PWD?dir=templates/fleet#tests" fleet   (e2e: suite e2e)
# The fleet flake passes its own inputs (pure, for fastest); a plain file eval reads them from the flake.
{
  inputs ? (builtins.getFlake "path:${toString ../..}?dir=templates/fleet").inputs,
}:
let
  inherit (inputs.nixpkgs) lib;
  yen = inputs.yen.lib;
  b = builtins;
  # a fastest test: { expr; expected; }
  eq = expr: expected: { inherit expr expected; };
  yes = x: eq x true;
  no = x: eq x false;
  # the shared-pkgs comparison hosts (environment lab) stay out of checks that list the original fleet
  noApps =
    xs:
    if lib.isAttrs xs then
      lib.filterAttrs (n: _: !lib.hasPrefix "app-" n && !lib.hasPrefix "infra-app-" n) xs
    else
      lib.filter (
        n:
        let
          s = if lib.isString n then n else "";
        in
        !(lib.hasInfix "app-" s)
      ) xs;
  fleet = extra: {
    imports = [ (inputs.import-tree ./modules) ] ++ extra;
    inherit inputs lib;
  };
  r = yen.eval (fleet [ ]);
  with' = m: yen.eval (fleet [ m ]);
  msgs = q: map (e: e.error) q.errors;
  hasMsg = q: re: lib.any (m: builtins.match re m != null) (msgs q);
  out = r.flake;

  P = "fleet:main/environment:prod";
  S = "fleet:main/environment:staging";
  lb = "${P}/host:lb";
  web1 = "${P}/host:web-1";
  web2 = "${P}/host:web-2";
  stage = "${S}/host:stage";
  ci = "${stage}/guest:ci";
  studio = "${S}/mac:studio";
  laptop = "fleet:main/home:alice-laptop";
  red = sink: id: r.reduced.${sink}.${id} or null;
  list = v: if lib.isList v then v else [ ];
  first = xs: if xs == [ ] then null else lib.head xs;
  names =
    xs:
    let
      v = first xs;
    in
    if lib.isAttrs v then lib.attrNames v else [ ];
  on = a: lib.filter (id: r.active.${a}.${id}) (lib.attrNames r.active.${a});
  edge =
    sink: from: to:
    lib.any (e: e.sink == sink && e.from == from && e.to == to) r.graph.edges;
  gave =
    origin: sink: to:
    lib.any (e: e.origin == origin && e.sink == sink && e.to == to) r.graph.edges; # projected hasAspect: what an aspect delivered where
  scope = id: lib.findFirst (s: s.id == id) null r.scopes;
  at = path: v: lib.attrByPath path null v;
  nixosAt = id: path: lib.filter (v: v != null) (map (at path) (list (red "nixos" id)));
  osAt = id: path: lib.filter (v: v != null) (map (at path) (list (red "os" id)));
  hmAt = id: path: lib.filter (v: v != null) (map (at path) (list (red "homeManager" id)));
  upTo = kinds: s: lib.findFirst (x: lib.elem x.kind kinds) null (lib.reverseList s.up);

  checks = {
    # ── Ren expected-results ──
    no-errors = eq (msgs r) ([ ]);
    docs-mermaid = {
      t1 = yes (lib.hasInfix "-->|\"nixos\"|" out.docs.mermaid);
      t2 = yes (edge "nixos" ci stage);
    };
    fold-one = eq (out.deploy.nodes.lb.hostname) ("10.0.1.1");
    fold-one-two-emitters = yes (
      hasMsg (with' (
        { yen, ... }:
        {
          yen.aspects.deploy2 = {
            at = yen.host.lb;
            deploy = {
              address = "x";
              user = "y";
            };
          };
        }
      )) "one: got 2 elements"
    );
    fold-list-order = eq (red "backends" P) ([
      "10.0.1.10"
      "10.0.1.11"
    ]);
    guest-channel-stable = {
      t1 = eq ((scope ci).channel.name) ("stable");
      t2 = eq ((scope stage).channel.name) ("edge");
    };
    guest-pkgs-stable = eq ((first (
      nixosAt stage [
        "microvm"
        "vms"
        "ci"
        "pkgs"
      ]
    )).path
    ) (inputs.nixpkgs.legacyPackages.x86_64-linux.path);
    chained-forward = {
      t1 = yes (edge "os" "${ci}/user:bob" ci);
      t2 = yes (edge "nixos" ci stage);
      t3 = no (
        (lib.any (u: u ? bob) (
          nixosAt stage [
            "home-manager"
            "users"
          ]
        ))
      );
    };
    darwin-not-nixos = {
      t1 = yes (out ? darwinConfigurations.studio);
      t2 = no ((out.nixosConfigurations ? studio));
      t3 = no ((out.nixosConfigurations ? ci));
    };
    kernel-not-on-studio = {
      t1 = no (r.active.kernel.${studio});
      t2 = yes (r.active.kernel.${lb});
    };
    ssh-agent-not-standalone = {
      t1 = no (r.active.ssh-agent."${laptop}/user:alice");
      t2 = yes (r.active.ssh-agent."${lb}/user:alice");
    };
    host-qualified-htop = eq (on "htop") ([ "${web1}/user:alice" ]);
    substitute-web2 = {
      t1 = no (r.active.motd.${web2});
      t2 = yes (r.active.motd-short.${web2});
      t3 = yes (r.active.motd.${web1});
    };
    has-docker = eq (lib.sort (a: b: a < b) (on "docker")) ([
      stage
      ci
    ]);
    parent-devices =
      eq
        (names (
          hmAt "${lb}/user:alice" [
            "services"
            "syncthing"
            "settings"
            "devices"
          ]
        ))
        ([
          "alice-laptop"
          "alice@stage"
          "ci"
          "lb-minimal"
          "pixel"
          "stage"
          "studio"
          "web-1"
          "web-2"
        ]);
    per-system = {
      t1 = eq (lib.attrNames out.packages) ([
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ]);
      t2 = yes (lib.all (p: p ? hello) (lib.attrValues out.packages));
    };
    overlays-once = eq (lib.length (red "overlays" "fleet:main")) (1);
    persist-stage = eq (lib.sort (a: b: a < b) (red "persist" stage)) ([
      "/home/alice/.local/state/syncthing"
      "/home/bob/.local/state/syncthing"
      "/var/lib/docker"
      "/var/lib/nginx"
    ]);
    persist-ci-own = yes (lib.elem "/var/lib/docker" (red "persist" ci));
    output-merge-equal = eq (msgs (
      with' (
        { yen, ... }:
        {
          yen.aspects.same-hello = {
            at = yen.system.x86_64-linux;
            packages.greeting = "hi";
          };
          yen.aspects.same-hello2 = {
            at = yen.system.x86_64-linux;
            packages.greeting = "hi";
          };
        }
      )
    )) ([ ]);
    output-merge-conflict = yes (
      hasMsg (with' (
        { yen, ... }:
        {
          yen.aspects.c1 = {
            at = yen.system.x86_64-linux;
            packages.greeting = "a";
          };
          yen.aspects.c2 = {
            at = yen.system.x86_64-linux;
            packages.greeting = "b";
          };
        }
      )) "merge conflict at greeting"
    );
    bare-overlay-refused = yes (
      hasMsg (with' (
        { yen, ... }:
        {
          yen.aspects.bare = {
            at = yen.fleet.main;
            overlays = final: prev: { };
          };
        }
      )) ".*bare function.*"
    );
    home-darwin-only-studio = eq (lib.attrNames r.reduced.homeDarwin) ([
      "${studio}/user:alice"
      "${studio}/user:bob"
    ]);
    tags-stage-web = yes (lib.elem "web" (red "tags" stage));
    flake-file-inputs = eq (lib.attrNames (red "flake-file" "fleet:main").inputs) (
      lib.attrNames (import ./flake.nix).inputs
    ); # the generated flake.nix has exactly the declared inputs
    flake-file-conflict = yes (
      hasMsg (with' (
        { yen, ... }:
        {
          yen.aspects.agenix2 = {
            at = yen.fleet.main;
            flake-file.inputs.agenix.url = "github:other/agenix";
          };
        }
      )) "merge conflict at inputs.agenix.url"
    );
    recursive-attrs-deploy = eq (noApps (lib.attrNames out.deploy.nodes)) ([
      "lb"
      "lb-minimal"
      "stage"
      "web-1"
      "web-2"
    ]);
    recursive-attrs-colmena = eq (noApps (lib.attrNames r.reduced.colmena."fleet:main")) ([
      "lb"
      "lb-minimal"
      "stage"
      "web-1"
      "web-2"
    ]);
    root-emission = eq ((red "flake-file" "fleet:main").inputs.nixpkgs.url) (
      "github:nixos/nixpkgs/nixos-25.05"
    );
    spawn-pixel-only-alice = {
      t1 = yes (lib.filter (s: s.parent != null && s.parent.id == "${S}/phone:pixel") r.scopes != [ ]);
      t2 = eq (map (s: s.name) (
        lib.filter (s: s.parent != null && s.parent.id == "${S}/phone:pixel") r.scopes
      )) ([ "alice" ]);
    };
    spawn-lb-only-alice = eq (map (s: s.name) (
      lib.filter (s: s.parent != null && s.parent.id == lb && s.kind == "user") r.scopes
    )) ([ "alice" ]);
    data-kinds-no-scopes = no (
      (lib.any (
        s:
        lib.elem s.kind [
          "group"
          "machine"
          "channel"
          "db"
          "region"
        ]
      ) r.scopes)
    );
    tray-stage-not-lb = {
      t1 = eq (hmAt "${stage}/user:alice" [
        "services"
        "syncthing"
        "tray"
        "enable"
      ]) ([ true ]);
      t2 = eq (hmAt "${lb}/user:alice" [
        "services"
        "syncthing"
        "tray"
        "enable"
      ]) ([ false ]);
    };
    into-outputs = {
      t1 = yes (out ? colmenaHive);
      t2 = yes (out ? ageManifest);
      t3 = yes (out ? packages);
      t4 = yes (out ? terraformConfigurations);
    };
    inventory-json = {
      t1 = yes ((scope web1) != null);
      t2 = eq ((scope web2).buildHost) ("10.0.1.1");
    };
    inventory-string-ref-refused = yes (
      hasMsg (with' {
        yen.host.bad = {
          environment = "prod";
          addr = "x";
        };
      }) ".*environment wants a environment ref.*"
    );
    vars = {
      t1 = eq (out.vars.shared.ca.files) ([
        "ca.crt"
        "ca.key"
      ]);
      t2 = eq (noApps (lib.attrNames out.vars.per-machine)) ([
        "lb"
        "lb-minimal"
        "stage"
        "web-1"
        "web-2"
      ]);
    };
    checks-names = {
      t1 = eq (noApps (lib.attrNames out.checks.x86_64-linux)) ([
        "files/README.md"
        "files/ci.json"
        "flake-file"
        "guard-pod"
        "infra-lb"
        "infra-stage"
        "infra-web-1"
        "infra-web-2"
        "lb-no-gui"
        "pre-commit"
      ]);
      t2 = no ((out.checks.x86_64-linux ? web));
      t3 = yes (out.vmTests.x86_64-linux ? web);
      t4 = no ((out.vmTests ? aarch64-linux));
      t5 = yes (out.checks.aarch64-linux ? pre-commit);
    };
    buildhost = {
      t1 = eq ((red "deploy" web2).buildHost) ("10.0.1.1");
      t2 = eq ((red "deploy" lb).buildHost) (null);
      t3 = eq (red "deploy" ci) (null);
    };
    facter-metal = eq (noApps (on "facter")) ([
      lb
      "${lb}/host:lb-minimal"
      web1
      web2
      stage
    ]);
    typed-scrape = eq (red "scrape" "fleet:main") ([
      {
        job = "r1";
        target = "eu.eu:9090";
      }
    ]);
    typed-scrape-bad = yes (
      hasMsg (with' (
        { yen, ... }:
        {
          yen.aspects.bad-scrape = {
            at = yen.host.lb;
            scrape.job = 1;
          };
        }
      )) ".*fails `of`.*"
    );
    diamond-nginx-once = {
      t1 = eq (lib.length (
        nixosAt web1 [
          "services"
          "nginx"
          "enable"
        ]
      )) (1);
      t2 = eq (lib.length (
        nixosAt stage [
          "services"
          "nginx"
          "enable"
        ]
      )) (1);
    };
    merge-across-files = {
      t1 = yes (r.active.base.${lb});
      t2 = eq (noApps (lib.attrNames (red "records" "fleet:main"))) ([
        "ci"
        "lb"
        "lb-minimal"
        "stage"
        "studio"
        "web-1"
        "web-2"
      ]);
    };
    recursive-kinds = yes (
      scope "fleet:main/domain:example.org/domain:api.example.org/domain:v1.api.example.org" != null
    );
    twice-on-path = yes (
      hasMsg (with' (
        { yen, ... }:
        {
          yen.kinds.fleet.spawns.ring = _: { r = { }; };
          yen.kinds.ring.spawns.ring = s: { r = { }; };
        }
      )) ".*instance ring:r twice on path.*"
    );
    nearest-bob-ci = {
      t1 = eq ((upTo [ "host" "guest" "mac" ] (scope "${ci}/user:bob")).id) (ci);
      t2 = eq ((upTo [ "environment" ] (scope "${ci}/user:bob")).name) ("staging");
      t3 = eq (upTo [ "environment" ] (scope "fleet:main")) (null);
    };
    graph-query = eq (lib.length r.graph.scopes) (lib.length r.scopes);
    # ── sini ──
    k3s-cluster-only = eq (lib.sort (a: b: a < b) (on "k3s")) ([
      web1
      web2
    ]);
    k3s-discovery = {
      t1 = eq (out.k8sManifests.axon.applications.k3s.nodes) ([
        "10.0.1.10"
        "10.0.1.11"
      ]);
      t2 = eq (out.k8sManifests.axon.target.branch) ("main");
    };
    k3s-bootstrap = {
      t1 = eq (nixosAt web1 [
        "services"
        "k3s"
        "clusterInit"
      ]) ([ true ]);
      t2 = eq (nixosAt web1 [
        "services"
        "k3s"
        "serverAddr"
      ]) ([ ]);
      t3 = eq (nixosAt web2 [
        "services"
        "k3s"
        "serverAddr"
      ]) ([ "https://10.0.1.10:6443" ]);
    };
    acl-sso-only = {
      t1 = eq (red "idm-users" P) ([ "dana" ]);
      t2 = no (lib.any (s: s.kind == "user" && s.name == "dana") r.scopes);
    };
    acl-host-grants = {
      t1 = eq (scope "${web2}/user:bob") (null);
      t2 = yes (
        lib.any (s: s.id == "${web2}/user:bob")
          (with' (
            { yen, ... }:
            {
              yen.host.web-2.grants = [ yen.group.deploy ];
            }
          )).scopes
      );
    };
    acl-host-gates = {
      t1 = yes (scope "${lb}/user:alice" != null);
      t2 = no (
        lib.any (s: s.id == "${lb}/user:alice")
          (with' (
            { yen, ... }:
            {
              yen.host.lb.gates = [ yen.group.deploy ];
            }
          )).scopes
      );
    };
    inference-allow = eq (nixosAt lb [
      "environment"
      "etc"
      "inference/allow"
      "text"
    ]) ([ "10.0.1.10\n10.0.2.10\n" ]);
    inference-no-address = yes (
      hasMsg (with' (
        { yen, ... }:
        {
          yen.host.web-2.settings.inference.clients = [ "ghost" ];
        }
      )) ".*client ghost has no address.*"
    );
    guard-named-host = eq (out.k8sManifests.axon.applications.guard.hub) ("alice@lb");
    join-upstreams = eq (out.k8sManifests.axon.applications.gateway.listeners) ([
      "web-1.example.org"
    ]);
    join-env-scoped = eq ((with' (
      { yen, ... }:
      {
        yen.aspects.stage-up = {
          at = yen.host.stage;
          served-domains = [ "stage.example.org" ];
          gateway-upstreams = {
            address = "10.0.2.10";
            exclude = [ ];
          };
        };
      }
    )).flake.k8sManifests.axon.applications.gateway.listeners
    ) ([ "web-1.example.org" ]);
    guest-intent-parent = {
      t1 = eq (nixosAt stage [
        "environment"
        "etc"
        "vfio/ids"
        "text"
      ]) ([ "10de:2203" ]);
      t2 = no (r.active.vfio.${lb});
      t3 = yes (
        (
          let
            r2 = with' (
              { yen, ... }:
              {
                yen.guest.gpu = {
                  environment = yen.environment.prod;
                  channel = yen.channel.stable;
                  system = yen.system.x86_64-linux;
                  addr = "10.0.1.30";
                  on = yen.host.lb;
                  passthrough = [ "1002:744c" ];
                };
              }
            );
            vf =
              id:
              lib.filter (v: v != null) (
                map (lib.attrByPath [ "environment" "etc" "vfio/ids" "text" ] null) (
                  list (r2.reduced.nixos.${id} or null)
                )
              );
          in
          vf stage == [ "10de:2203" ] && vf lb == [ "1002:744c" ]
        )
      );
    };
    factories = yes (
      map (z: "${z.account}:${z.zone}") (red "dns-zones" "fleet:main") == [
        "api:api.example.org"
        "json64:example.org"
      ]
      ||
        map (z: "${z.account}:${z.zone}") (red "dns-zones" "fleet:main") == [
          "json64:example.org"
          "api:api.example.org"
        ]
    );
    unit-check-stand-in = {
      t1 = yes (out.checks.x86_64-linux ? guard-pod);
      t2 = eq (red "unit-checks" "fleet:main") ({ guard-pod = true; });
    };
    one-edge = yes (
      hasMsg (with' (
        { yen, ... }:
        {
          yen.environment.staging.dns.publicIPv4 = "198.51.100.1";
        }
      )) "dns: 2 environments set dns.publicIPv4.*"
    );
    ingest-across-envs = {
      t1 = eq (nixosAt web1 [
        "environment"
        "etc"
        "alloy/endpoints"
        "text"
      ]) ([ "https://ingest.example.org\n" ]);
      t2 = eq (nixosAt stage [
        "environment"
        "etc"
        "alloy/endpoints"
        "text"
      ]) ([ "" ]);
    };
    domains-records = {
      t1 = eq (map (e: e.value.name) (red "dns-records" "fleet:main")) ([ "example.org" ]);
      t2 = eq (lib.length (red "certificate-domains" "fleet:main")) (3);
    };
    terranix-conditional = {
      t1 = yes (out ? terranixConfigurations.dns-prod);
      t2 = no ((out.terranixConfigurations ? dns-staging));
    };
    unifi-forwards = {
      t1 = yes (out.unifiTerranixModules.prod != [ ]);
      t2 = eq (lib.length (red "port-forwards" P)) (1);
    };
    home-linux = {
      t1 = yes (r.reduced.homeLinux ? "${lb}/user:alice");
      t2 = no ((r.reduced.homeLinux ? "${studio}/user:alice"));
      t3 = no ((r.reduced.homeLinux ? "${laptop}/user:alice"));
    };
    primary-user = eq (on "primary-user") ([
      "${lb}/host:lb-minimal/user:alice"
      "${lb}/user:alice"
    ]);
    syncthing-hub = {
      t1 = eq (on "syncthing-hub") ([ stage ]);
      t2 =
        eq
          (names (
            nixosAt stage [
              "services"
              "syncthing"
              "settings"
              "folders"
            ]
          ))
          ([
            "alice-home"
            "bob-home"
          ]);
    };
    syncthing-peers =
      eq
        (first (
          hmAt "${lb}/user:alice" [
            "home"
            "file"
            ".syncthing-peers"
            "text"
          ]
        ))
        (
          builtins.toJSON [
            "lb-minimal"
            "web-1"
            "web-2"
            "ci"
            "alice@stage"
            "stage"
          ]
        ); # scope order: guest:ci and home:alice@stage sort before user:alice
    unpersist-web2 =
      let
        d =
          id:
          first (
            nixosAt id [
              "environment"
              "persistence"
              "/persist"
              "directories"
            ]
          );
      in
      {
        t1 = no ((lib.elem "/var/lib/nginx" (d web2)));
        t2 = yes (lib.elem "/var/lib/nginx" (d web1));
        t3 = yes (lib.elem "/var/lib/nginx" (red "persist" web2));
      };
    tags-from-roles = {
      t1 = eq (r.reduced.colmena."fleet:main".stage.deployment.tags) ([
        "staging"
        "web"
        "workstation"
        "laptop"
      ]);
      t2 = eq (r.reduced.colmena."fleet:main".lb.deployment.tags) ([
        "prod"
        "server"
      ]);
    };
    profile-not-guests = {
      t1 = yes (r.active.desktop.${stage});
      t2 = no (r.active.desktop.${ci});
      t3 = yes (r.active.thermald.${stage});
    };
    unfree-set = eq (red "unfree" stage) ([ "terraform" ]);
    xmsg-trust = eq (hmAt "${lb}/user:alice" [
      "home"
      "file"
      ".xmsg-peers"
      "text"
    ]) ([ (builtins.toJSON [ "bob" ]) ]);
    flake-level = {
      t1 = yes (out ? devShells.x86_64-linux.default);
      t2 = yes (out ? formatter.x86_64-linux);
      t3 = yes (out.packages.x86_64-linux ? greet);
      t4 = yes (out.packages.x86_64-linux ? k8s-all);
      t5 = yes (out ? overlays.default);
    };
    settings-cascade = {
      t1 = eq (nixosAt web1 [
        "boot"
        "kernelParams"
      ]) ([ [ "zfs.zfs_arc_max=8589934592" ] ]);
      t2 = eq (nixosAt stage [
        "boot"
        "kernelParams"
      ]) ([ [ "zfs.zfs_arc_max=4294967296" ] ]);
      t3 = eq (nixosAt lb [
        "boot"
        "kernelParams"
      ]) ([ [ "zfs.zfs_arc_max=4294967296" ] ]);
    };
    relation-kind = {
      t1 = yes (scope "fleet:main/replica:r1" != null);
      t2 = eq (scope "fleet:main/replica:r2") (null);
    };
    # ── Den ──
    den-specialisation = {
      t1 = yes (edge "nixos" "${lb}/variant:debug" lb);
      t2 = yes (
        nixosAt lb [
          "specialisation"
          "debug"
          "configuration"
          "imports"
        ] != [ ]
      );
    };
    den-ids = {
      t1 = eq (nixosAt lb [
        "services"
        "openssh"
        "ports"
      ]) ([ [ 2204 ] ]);
      t2 = eq (nixosAt web2 [
        "services"
        "openssh"
        "ports"
      ]) ([ [ 2208 ] ]); # app-1..4 sort first
    };
    den-module-outside = {
      t1 = yes (lib.isList (red "nixos" lb));
      t2 = yes (lib.length (red "nixos" lb) > 10); # moduleOf: a query gives the module list
    };
    den-nested-groups = eq (lib.length (
      lib.filter (s: s.kind == "user" && s.name == "alice") r.scopes
    )) (10);
    den-739-home-on-host = {
      t1 = yes (edge "homeManager" "${stage}/home:alice@stage/user:alice" "${stage}/home:alice@stage");
      t2 = eq (hmAt "${stage}/home:alice@stage" [
        "home"
        "sessionVariables"
        "MONITORRES"
      ]) ([ "2560x1440" ]);
      t3 = eq (hmAt "${stage}/user:alice" [
        "home"
        "sessionVariables"
        "MONITORRES"
      ]) ([ ]);
    };
    den-739-not-in-host-hm = no ((edge "os" "${stage}/home:alice@stage/user:alice" stage));
    # ── swarsel ──
    swarsel-variant = {
      t1 = yes (scope "${lb}/host:lb-minimal" != null);
      t2 = no (r.active.haproxy."${lb}/host:lb-minimal");
      t3 = yes (out.nixosConfigurations ? lb-minimal);
    };
    swarsel-nodes =
      let
        xs = id: map (m: m.networking.extraHosts or null) (lib.concatLists (nixosAt id [ "imports" ]));
      in
      {
        t1 = yes (lib.elem "10.0.1.1 lb.internal" (xs web1));
        t2 = no ((lib.elem "10.0.1.1 lb.internal" (xs stage)));
      };
    swarsel-globals = eq ((first (
      nixosAt lb [
        "networking"
        "hosts"
      ]
    )).${"10.0.1.10"}
    ) ([ "web-1.fleet" ]);
    swarsel-export = eq (lib.length out.nixosModules.base.imports) (2);
    # ── sini mesh, adda, vix ──
    sini-mesh-peers =
      eq
        (map (p: p.endpoint) (
          first (
            nixosAt web1 [
              "networking"
              "wireguard"
              "interfaces"
              "mesh"
              "peers"
            ]
          )
        ))
        ([
          "10.0.1.1:51820"
          "10.0.1.11:51820"
        ]);
    sini-nix-builders = {
      t1 =
        eq
          (first (
            nixosAt lb [
              "nix"
              "buildMachines"
            ]
          ))
          ([
            {
              hostName = "10.0.1.10";
              system = "x86_64-linux";
            }
          ]);
      t2 = eq (first (
        nixosAt web1 [
          "nix"
          "buildMachines"
        ]
      )) ([ ]);
    };
    adda-caddy =
      eq
        (names (
          nixosAt lb [
            "services"
            "caddy"
            "virtualHosts"
          ]
        ))
        ([
          "grafana.example.org"
          "status.example.org"
        ]);
    adda-templates = eq (out.templates.default.description) ("A yen fleet");
    vix-vim-features = {
      t1 = eq (red "vimrc" "${"fleet:main/system:x86_64-linux"}/vim:dev") ([
        "vim.o.number = true"
        "require('gitsigns').setup()"
        "vim.lsp.enable('nixd')"
        "vim.cmd.colorscheme('tokyonight')"
      ]);
      t2 = eq (red "vimrc" "fleet:main/system:x86_64-linux/vim:min") ([ "vim.o.number = true" ]);
      t3 = yes (out.packages.x86_64-linux ? vim-dev);
      t4 = yes (lib.hasInfix "vim.lsp.enable" out.packages.x86_64-linux.vim-dev.text); # the package text: the arg reads the sink, not the kind
    };
    vix-secrets = {
      t1 = eq (map (s: s.name) (red "secrets" "${stage}/user:bob")) ([
        "gh-token"
        "gpg-key"
      ]);
      t2 = eq (map (s: s.name) (red "secrets" "${lb}/user:alice")) ([ "gh-token" ]);
    };
    # ── checks derived from the infra ──
    ci-matrix = eq (noApps (map (j: j.name) out.ci.matrix)) ([
      "alice-laptop"
      "alice@stage"
      "devshell-aarch64-darwin"
      "devshell-aarch64-linux"
      "devshell-x86_64-linux"
      "lb"
      "stage"
      "studio"
      "web-1"
      "web-2"
    ]);
    infra-facts = {
      t1 = eq (lib.attrNames (red "infra" "fleet:main").lb) ([
        "hostname"
        "persist /home/alice/.local/state/syncthing"
      ]);
      t2 = eq (lib.attrNames (red "infra" "fleet:main").web-1) ([
        "hostname"
        "nginx"
        "persist /home/alice/.local/state/syncthing"
        "persist /var/lib/nginx"
        "port80"
      ]);
    };
    # ── Den CI capabilities (templates/ci/modules) ──
    den-batteries = {
      t1 = eq (osAt stage [
        "services"
        "getty"
        "autologinUser"
      ]) ([ ]);
      t2 = eq (osAt ci [
        "services"
        "getty"
        "autologinUser"
      ]) ([ "bob" ]);
      t3 = eq (osAt stage [
        "nixpkgs"
        "config"
        "permittedInsecurePackages"
      ]) ([ [ "olm-3.2.16" ] ]);
      t4 = yes (r.active.global-pkgs.${lb});
      t5 = no (r.active.global-pkgs."fleet:main/environment:prod/cluster:axon");
    };
    den-chained-forward = {
      t1 = yes (edge "git" "${lb}/user:alice" "${lb}/user:alice");
      t2 = yes (gave "sink git" "homeManager" "${lb}/user:alice");
      t3 = yes (gave "sink homeManager" "os" lb);
    };
    den-custom-class-no-hm = {
      t1 = eq (gave "sink maid" "os" "${stage}/user:bob") (false);
      t2 = yes (gave "sink maid" "os" stage);
      t3 = no ((gave "sink maid" "os" lb));
      t4 = no ((gave "sink maid" "os" studio)); # maid: linux only, never darwin
    };
    den-609-host-hm-no-leak = {
      t1 = eq (msgs (
        with' (
          { yen, ... }:
          {
            yen.aspects.host-hm = {
              at = yen.host.lb;
              homeManager.programs.htop.enable = true;
            };
          }
        )
      )) ([ ]);
      t2 = no (
        (lib.any (e: e.origin == "aspect host-hm")
          (with' (
            { yen, ... }:
            {
              yen.aspects.host-hm = {
                at = yen.host.lb;
                homeManager.programs.htop.enable = true;
              };
            }
          )).graph.edges
        )
      );
    };
    den-projected-has-aspect = {
      t1 = yes (gave "aspect dev" "os" lb);
      t2 = yes (gave "aspect dev" "homeManager" "${lb}/user:alice");
      t3 = no ((gave "aspect desktop" "nixos" ci));
    };
    den-525-structure-from-presence = {
      t1 = eq (map (s: s.id) (lib.filter (s: s.kind == "backup") r.scopes)) ([
        "${lb}/backup:nightly"
        "${web1}/backup:nightly"
        "${web2}/backup:nightly"
      ]);
      t2 =
        eq
          (nixosAt lb [
            "services"
            "restic"
            "backups"
            "nightly"
            "paths"
          ])
          ([
            [
              "/persist"
              "/etc/lb"
            ]
          ]);
    };
    den-instance-side-include = {
      t1 = yes (r.active.desktop.${stage});
      t2 = yes (r.active.motd."fleet:main/export:base");
    };
    den-permutation-stable =
      let
        rev = yen.eval {
          imports = lib.reverseList (import ./_modules-list.nix);
          inherit inputs lib;
        };
        j =
          q:
          builtins.toJSON (
            map (k: q.reduced.${k}) [
              "persist"
              "backends"
              "records"
              "tags"
              "vimrc"
              "secrets"
              "ci"
            ]
          );
      in
      {
        t1 = eq (j rev) (j r);
        t2 = eq (map (s: s.id) rev.scopes) (map (s: s.id) r.scopes);
      };
    den-sibling-laziness =
      let
        p = with' (
          { yen, ... }:
          {
            yen.aspects.poison = {
              at = yen.host.web-2;
              nixos = throw "poisoned web-2";
            };
          }
        );
      in
      # the tree stays lazy; values need a verdict (D13), and a throwing sibling leaves none
      {
        tree = eq (lib.length p.scopes) (lib.length r.scopes);
        no-values = no (builtins.tryEval (p.reduced == null)).success;
      };

    # ── Den CI usage patterns (vic/den-patterns.md) ──
    den-cartesian-and-transitive = {
      t1 = eq (lib.sort (a: b: a < b) (red "pairs" stage)) ([
        "alice-fido"
        "alice-rex"
        "bob-fido"
        "bob-rex"
        "rex/ball"
        "rex/bone"
      ]);
      t2 = eq (red "pairs" lb) (null);
    };
    den-user-classes = {
      t1 = yes (gave "sink maid" "os" stage);
      t2 = no ((r.reduced.maid ? "${stage}/user:alice"));
    };
    den-enrichment-sinks = {
      t1 = eq (red "isNixos" lb) (true);
      t2 = eq (red "platform" lb) ("linux");
      t3 = eq (nixosAt lb [
        "environment"
        "variables"
        "PLATFORM"
      ]) ([ "linux" ]);
    };
    den-user-packages-per-system = yes (
      lib.all (n: out.packages.x86_64-linux ? ${n}) [
        "sw-lb-alice"
        "sw-stage-bob"
        "sw-web-1-alice"
      ]
    );
    den-opt-in-projection = {
      t1 = eq (hmAt "${stage}/user:alice" [
        "home"
        "sessionVariables"
        "HMVALS"
      ]) ([ "user" ]);
      t2 = eq (hmAt "${stage}/user:alice" [
        "home"
        "sessionVariables"
        "HOST_ENV"
      ]) ([ "staging" ]);
      t3 = eq (hmAt "${stage}/user:bob" [
        "home"
        "sessionVariables"
        "HMVALS"
      ]) ([ ]);
    };
    den-pipeline-stage = {
      t1 = eq (nixosAt lb [
        "networking"
        "firewall"
        "allowedTCPPorts"
      ]) ([ [ 80 ] ]);
      t2 = eq (lib.length (red "fw" lb)) (2);
    };
    den-one-class-two-systems = {
      t1 = yes (gave "sink both" "os" stage);
      t2 = yes (gave "sink both" "homeManager" "${stage}/user:bob");
    };
    den-broadcast =
      let
        p = first (
          nixosAt lb [
            "environment"
            "etc"
            "peers"
            "text"
          ]
        );
      in
      {
        t1 = yes (lib.hasInfix "bob@stage" p);
        t2 = no ((lib.hasInfix "alice@lb," p));
        t3 = no ((lib.hasSuffix "alice@lb" p));
      };
    den-producer-own-config = eq (hmAt "${stage}/user:alice" [
      "home"
      "sessionVariables"
      "DEV"
    ]) ([ "h:stage" ]);
    # ── den-hoag (Den + Gen) capabilities ──
    hoag-settings-authority = {
      t1 = eq ((red "aspect-settings" web1).nginx) ({
        gzip = true;
        workers = 8;
      });
      t2 = eq ((red "aspect-settings" web2).nginx.workers) (4);
      t3 = eq ((red "aspect-settings" stage).nginx) ({
        gzip = false;
        workers = 1;
      });
    };
    hoag-settings-conflict = yes (
      hasMsg (with' (
        { yen, ... }:
        {
          yen.aspects.t2 = {
            at = yen.host.web-1;
            aspect-settings = {
              rank = 2;
              set.nginx.workers = 9;
            };
          };
        }
      )) "aspect-settings: two layers of rank 2 disagree"
    );
    hoag-ci-strategies = {
      t1 = eq ((red "tuning" lb).value) ({
        ports = [
          22
          80
          443
        ];
        color = "blue";
        accent = "blue";
      });
      t2 = eq ((red "tuning" stage).value.ports) ([ 22 ]);
      t3 = eq (map (p: p.rank) (red "tuning" lb).provenance.ports) ([
        0
        1
        2
      ]);
    };
    hoag-ci-claim-dedup = eq (red "token-claims" "fleet:main") ({
      apitoken.sharers = [
        "web-1"
        "web-2"
      ];
      metrics.sharers = [ "web-1" ];
    });
    hoag-ci-lockdown = {
      t1 = eq (nixosAt lb [
        "environment"
        "etc"
        "db/lockdown"
        "text"
      ]) ([ "web-2" ]);
      t2 = eq (nixosAt stage [
        "environment"
        "etc"
        "db/lockdown"
        "text"
      ]) ([ "" ]);
    };
    hoag-ci-route-split = {
      t1 = eq (red "secret-claims" "fleet:main") ({
        api.by = "web-1";
      });
      t2 = eq (red "connect-claims" "fleet:main") ({ api.by = "web-1"; });
    };
    hoag-ci-demand-cascade = {
      t1 =
        eq
          (lib.sort (a: b: a < b) (
            map (s: s.id) (
              lib.filter (
                s:
                lib.elem s.kind [
                  "database"
                  "secret"
                  "connect"
                ]
              ) r.scopes
            )
          ))
          ([
            "fleet:main/database:audit"
            "fleet:main/database:audit/connect:audit-url"
            "fleet:main/database:audit/secret:audit-pw"
            "fleet:main/database:orders"
            "fleet:main/database:orders/connect:orders-url"
            "fleet:main/database:orders/secret:orders-pw"
            "fleet:main/database:users"
            "fleet:main/database:users/connect:users-url"
            "fleet:main/database:users/secret:users-pw"
          ]);
      t2 = eq ((scope "fleet:main/database:orders").by) ([
        "web-1"
        "web-2"
      ]);
    };
    hoag-ci-visible = eq (out.visibleMotd) ({
      a = "w1";
      b = "w2";
      w = "w1";
    });
    hoag-ci-suppress-chain =
      eq
        (map (a: r.active.${a}.${lb}) [
          "sup-a"
          "sup-b"
          "sup-c"
          "sup-d"
        ])
        ([
          true
          false
          true
          false
        ]);
    hoag-ci-class-share-per-class = {
      t1 = yes (out.classShare ? nixos);
      t2 = no ((out.classShare ? homeManager));
    };
    kits-members = {
      t1 =
        eq
          (lib.sort (a: b: a < b) (
            map (s: s.name) (lib.filter (s: s.kind == "member" && s.parent.id == lb) r.scopes)
          ))
          ([
            "backup-sshd.server"
            "backup.client"
            "backup.server"
            "sshd.server"
            "svc-a.default"
            "svc-b.default"
          ]);
      t2 =
        eq
          (lib.sort (a: b: a < b) (
            map (s: s.name) (lib.filter (s: s.kind == "member" && s.parent.id == studio) r.scopes)
          ))
          ([
            "banner.default"
            "sshd.server"
          ]);
    };
    kits-settings-layers = {
      t1 = eq (nixosAt stage [
        "environment"
        "etc"
        "wifi/networks"
        "text"
      ]) ([ "home office" ]);
      t2 = eq (nixosAt lb [
        "services"
        "borgbackup"
        "jobs"
        "backup"
        "startAt"
      ]) ([ "02:00" ]);
    };
    kits-interface-default = eq (osAt studio [
      "environment"
      "etc"
      "banner"
      "text"
    ]) ([ "managed by yen" ]);
    kits-multi-assembly =
      eq
        (lib.sort (a: b: a < b) (
          lib.concatMap lib.attrNames (
            nixosAt lb [
              "users"
              "users"
            ]
          )
        ))
        ([
          "svc-a"
          "svc-b"
        ]);
    kits-per-machine = {
      t1 = eq (lib.length (
        osAt lb [
          "services"
          "openssh"
          "enable"
        ]
      )) (1);
      t2 = yes (
        (
          let
            es = lib.filter (e: e.origin == "aspect kit-sshd") r.graph.edges;
          in
          es != [ ] && lib.all (e: e.from == e.to) es
        )
      );
      t3 = eq (lib.length (
        lib.filter (s: s.kind == "member" && s.parent.id == lb && s.kit.name == "sshd") r.scopes
      )) (2);
    };
    kits-exports = {
      t1 = eq (nixosAt web1 [
        "services"
        "borgbackup"
        "jobs"
        "backup"
        "repo"
      ]) ([ "borg@10.0.1.1:/srv/web-1" ]);
      t2 =
        eq
          (map (e: "${e.kit.name}:${e.assembly.name}:${e.role}:${e.machine.name}") (
            red "exports" "fleet:main"
          ))
          ([
            "borg:backup:server:lb"
            "site:docs:default:web-1"
          ]);
    };
    kits-exports-owned = {
      t1 = eq (map (e: e.kit.name) (red "exports" "fleet:main" ++ [ ])) ([
        "borg"
        "site"
      ]); # a forged export is an error, and an erroring fleet gives no reduced values (D13)
      t2 = yes (
        (
          let
            f = with' (
              { yen, ... }:
              {
                yen.aspects.forge = {
                  at = yen.lib.all [
                    yen.kinds.member
                    (s: yen.lib.same s.kit yen.kit.sshd)
                  ];
                  exports = {
                    kit = yen.kit.borg;
                  };
                };
              }
            );
          in
          hasMsg f ".*kit sshd does not export kit" && f.reduced == null
        )
      );
    };
    kits-exports-per-assembly =
      let
        x = with' (
          { yen, ... }:
          {
            yen.assembly.offsite = {
              kit = yen.kit.borg;
              roles = {
                client.at = yen.host.web-1;
                server.at = yen.host.web-2;
              };
            };
          }
        );
        job =
          n: map (v: v.services.borgbackup.jobs.${n}.repo or null) (list (x.reduced.nixos.${web1} or null));
      in
      {
        t1 = yes (lib.elem "borg@10.0.1.11:/srv/web-1" (job "offsite"));
        t2 = yes (lib.elem "borg@10.0.1.1:/srv/web-1" (job "backup"));
      };
    kits-role-union =
      let
        x = with' (
          { yen, ... }:
          {
            yen.assembly.mix = {
              kit = yen.kit.banner;
              roles.default.at = [
                yen.kinds.mac
                yen.host.web-1
              ];
            };
          }
        );
      in
      eq
        (lib.sort (a: b: a < b) (
          map (s: s.parent.name) (lib.filter (s: s.kind == "member" && s.assembly.name == "mix") x.scopes)
        ))
        ([
          "studio"
          "web-1"
        ]);
    kits-export-allowlist = yes (
      hasMsg (with' (
        { yen, ... }:
        {
          yen.aspects.leak = {
            at = yen.lib.all [
              yen.kinds.member
              (s: yen.lib.same s.kit yen.kit.borg && s.role == "server")
            ];
            exports =
              { scope, ... }:
              {
                token = "x";
              };
          };
        }
      )) ".*backup.server@lb: kit borg does not export token.*"
    );
    kits-export-override =
      let
        x = with' (
          { yen, ... }:
          {
            yen.aspects.owner-pin = {
              at = yen.kinds.fleet;
              exports = {
                assembly = yen.assembly.backup;
                role = "server";
                machine = yen.host.lb;
                value.repo = "borg@vault";
              };
            };
          }
        );
      in
      yes (
        lib.elem "borg@vault:/srv/web-1" (
          map (v: v.services.borgbackup.jobs.backup.repo or null) (list (x.reduced.nixos.${web1} or null))
        )
      );
    vars-plan =
      let
        p = out.varsPlan.web-1;
      in
      {
        t1 = yes (
          lib.elem {
            generator = "borg-backup";
            file = "passphrase";
            path = "/run/secrets-for-users/vars/borg-backup/passphrase";
            neededForUsers = true;
          } p.files
        );
        t2 = yes (
          lib.elem {
            generator = "openssh";
            file = "ssh.id_ed25519";
            path = "/run/secrets/vars/openssh/ssh.id_ed25519";
            neededForUsers = false;
          } p.files
        );
        t3 = eq (lib.findFirst (n: n == "openssh" || n == "borg-backup") null (map (g: g.name) p.order)) (
          "openssh"
        );
        t4 = yes (lib.any (f: f.generator == "wifi.home") out.varsPlan.stage.files);
        t5 = no ((lib.any (f: f.generator == "wifi.home") out.varsPlan.lb.files));
      };
    vars-export-generators = {
      t1 = eq ((red "generators" "fleet:main")."from-exports@web-1".files) ({
        "borg.known_hosts".secret = false;
      });
      t2 = no (((red "generators" "fleet:main") ? "from-exports@web-2"));
    };
    vars-secret-read = yes (
      hasMsg (with' (
        { yen, ... }:
        {
          yen.aspects.peek = {
            at = yen.host.web-1;
            public-reads = {
              machine = "web-1";
              generator = "openssh";
              file = "ssh.id_ed25519";
            };
          };
        }
      )) ".*web-1 reads openssh/ssh.id_ed25519, a secret file.*"
    );
    vars-store-consistency = yes (
      hasMsg (with' (
        { ... }:
        {
          yen.host.web-2.secretStore = "age";
        }
      )) ".*web-2 uses secret store age, the fleet uses sops.*"
    );
    vars-darwin-restart = yes (
      hasMsg (with' (
        { yen, ... }:
        {
          yen.assembly.backup-mac = {
            kit = yen.kit.borg;
            roles = {
              client.at = yen.mac.studio;
              server.at = yen.host.lb;
            };
          };
        }
      )) ".*borg-backup-mac: restartUnits is NixOS only.*"
    );
    vars-dir-hosts = {
      t1 = yes ((scope web2).fromDir);
      t2 = no ((lib.any (s: s.name == "notes.txt") r.scopes));
    };
    kits-cross-kit-exports = eq (out.cnames) ([
      {
        name = "docs.example.org";
        target = "web-1";
      }
    ]);
    vars-deploy-false = {
      t1 = no (lib.any (f: f.file == "ca-key") out.varsPlan.stage.files);
      t2 = yes (lib.any (f: f.file == "password") out.varsPlan.stage.files);
    };
    vars-recipients = {
      t1 = eq (out.varsPlan.lb.recipients) ([
        "age1lb"
        "age1admin"
      ]);
      t2 = eq (out.varsPlan.web-1.recipients) ([ "age1admin" ]);
    };
    graphs-impact = {
      t1 = eq (noApps out.impact) ({
        lb = [
          "stage"
          "web-1"
          "web-2"
        ];
        stage = [ ];
        web-1 = [ "stage" ];
        web-2 = [ ];
      });
      t2 = yes (
        hasMsg (with' (
          { yen, ... }:
          {
            yen.host.lb.dependsOn = [ yen.host.stage ];
          }
        )) "deploy: hosts depend on each other in a cycle: lb -> stage -> web-1"
      );
    };
    datalog-serving =
      let
        etc =
          r: f:
          lib.filter (v: v != null) (
            map (m: m.environment.etc.${f}.text or null) (list (r.reduced.nixos.${lb} or null))
          );
      in
      {
        t1 = eq (etc r "lb/serving") ([ "stage web-1 web-2" ]);
        t2 = eq (etc r "db/primary") ([ "lb" ]);
        t3 = eq (etc (with' (
          { ... }:
          {
            yen.host.web-2.maintenance = true;
          }
        )) "lb/serving") ([ "stage web-1" ]);
        t4 = eq (etc (with' (
          { ... }:
          {
            yen.host.web-1.maintenance = true;
          }
        )) "lb/serving") ([ "web-2" ]); # stage depends on web-1: drained too
        t5 = yes (lib.hasInfix "web:web-1" (lib.head (etc r "lb/why-web-1")));
      };
    krn-ports =
      let
        p = builtins.fromJSON (
          lib.head (
            lib.filter (v: v != null) (
              map (m: m.environment.etc."apps/ports".text or null) (list (red "nixos" lb))
            )
          )
        );
      in
      {
        t1 = eq (p) ({
          grafana = 8081;
          loki = 8082;
          prometheus = 8080;
        });
        t2 = yes (p.prometheus < p.grafana);
        t3 = eq (lib.length (lib.unique (lib.attrValues p))) (3);
        t4 = yes (
          hasMsg (with' (
            { ... }:
            {
              yen.host.web-2 = {
                apps = [
                  "a"
                  "b"
                ];
                portRange = [
                  9000
                  9000
                ];
              };
            }
          )) ".*no allocation for web-2: 2 apps, ports 9000 9000.*"
        );
      };
    krn-memory =
      let
        mem =
          x:
          lib.filter (v: v != null) (
            map (m: m.environment.etc."guests/memory".text or null) (list (x.reduced.nixos.${stage} or null))
          );
        guest =
          n: r:
          { yen, ... }:
          {
            yen.guest.${n} = {
              environment = yen.environment.staging;
              channel = yen.channel.stable;
              system = yen.system.x86_64-linux;
              addr = "10.0.2.3${toString (lib.length r)}";
              on = yen.host.stage;
              ramRange = r;
            };
          };
      in
      {
        t1 = eq (mem r) ([ (builtins.toJSON { ci = 8; }) ]);
        t2 =
          eq
            (mem (
              with' (
                guest "build" [
                  4
                  8
                ]
              )
            ))
            ([
              (builtins.toJSON {
                build = 8;
                ci = 2;
              })
            ]);
        t3 = yes (
          hasMsg (with' (
            guest "big" [
              9
              12
            ]
          )) ".*the guests of stage do not fit in 16 GiB with 6 reserved.*"
        );
        t4 = yes (
          (
            let
              x = with' (
                { ... }:
                {
                  yen.host.stage.ramFuel = 3;
                }
              );
            in
            hasMsg x ".*the search for stage ran out of fuel.*" && mem x == [ ]
          )
        );
      };
    krn-placement = {
      t1 = eq (noApps out.dbPlacement) ({
        lb = [ "lb" ];
        stage = [ "stage" ];
        web-1 = [ "lb" ];
        web-2 = [ "lb" ];
      });
      t2 = eq (lib.sort (a: b: a < b) out.takes8081) ([
        "grafana"
        "loki"
        "prometheus"
      ]);
    };
    agent-check = {
      t1 = yes (r.check.ok);
      t2 = yes (r.check.certified);
      t3 = eq (r.check.verify r.check.seal) ({ ok = true; });
      t4 = eq (r.check.invariants) ([
        "attic"
        "base"
        "db-exists"
        "db-same-env"
        "ssh"
        "trust-order"
        "unique-addr"
        "vocabulary"
      ]);
      t5 = eq (r.check.violations) ([ ]);
    };
    agent-stage =
      let
        s = yen.stage {
          base = fleet [ ];
          change = {
            yen.aspects.attic.at = [
              {
                kind = "mac";
                name = "studio";
              }
            ];
          };
        };
      in
      {
        t1 = no (s.ok);
        t2 = eq (s.violations) ([
          [
            "bad"
            "attic"
            studio
          ]
        ]);
        t3 = eq (s.diff.active.added) ([ "attic@${studio}" ]);
        t4 = yes (b.isString s.render);
      };
    agent-grant =
      let
        g = yen.grant { scopes = [ S ]; };
        st =
          to:
          yen.stage {
            base = fleet [ ];
            change = {
              yen.aspects.attic.at = [ to ];
            };
            grant = g;
          };
      in
      # D14-A: a change can reach every scope, so each scope outside the grant is refused, never one inside it
      {
        outside-only = yes (
          lib.all (e: e.code == "outside-grant" && !(lib.hasPrefix "${S}/" e.got) && e.got != S)
            (st {
              kind = "host";
              name = "stage";
            }).refused
        );
        some = yes (
          (st {
            kind = "host";
            name = "stage";
          }).refused != [ ]
        );
        web-1 = yes (
          lib.any (e: lib.hasSuffix "/host:web-1" e.got)
            (st {
              kind = "host";
              name = "web-1";
            }).refused
        );
      };
    agent-explain =
      let
        e = r.explain "attic" lb 2;
      in
      {
        t1 = yes (e.active);
        t2 = yes (lib.any (f: lib.hasSuffix "modules/sini/secrets.nix" f) e.files);
        t3 = yes (e.gives != [ ]);
      };
    agent-context =
      let
        c = r.context lb { maxEdges = 5; };
      in
      {
        t1 = eq (c.received.truncated.shown) (5);
        t2 = yes (c.received.truncated.of > 5);
        t3 = eq (b.fromJSON (b.toJSON c)) (c);
      };
    agent-schema = {
      t1 = eq (r.schema.kinds.host.sinks.deploy.reduce) ("one");
      t2 = eq (r.schema.kinds.environment.sinks.k3s-nodes.reduce) ("entries");
      t3 = eq (b.elem "sshd" (lib.attrNames r.schema.aspects)) (false);
      t4 = yes (r.schema.aspects.kit-sshd.activeAt > 0);
      t5 = eq (b.fromJSON (b.toJSON r.agent)) (r.agent);
    };
    agent-whynot =
      let
        w = out.serving.whyNot;
      in
      {
        t1 = yes (w.lb != [ ]);
        t2 = yes (lib.any (x: x.missing == [ "web:lb" ]) w.lb);
        t3 = eq (w.web-1) ([ ]);
        t4 = eq (out.serving.primary) ("unknown");
        t5 = yes (
          lib.hasInfix "serves:web-1" (
            lib.head (
              lib.filter (v: v != null) (
                map (m: m.environment.etc."lb/proof-web-1".text or null) (list (red "nixos" lb))
              )
            )
          )
        );
      };
    agent-rdf =
      let
        p = yen.rdf.share r;
        q = yen.rdf.share (
          yen.eval (fleet [
            (
              { yen, ... }:
              {
                yen.aspects.extra = {
                  at = yen.host.lb;
                  persist = "/var/lib/extra";
                };
              }
            )
          ])
        );
      in
      {
        t1 = yes (lib.hasPrefix "<" p.ntriples);
        t2 = yes (p.count > 1000);
        t3 = yes (p.sha256 != q.sha256);
        t4 = yes (out.rdfPack.count > 0);
        t5 = yes (b.isString out.rdfPack.sha256);
      };
    agent-queries = {
      t1 = eq (r.queries.hostsIn) ({
        required = [ "env" ];
        optional = [ ];
      });
      t2 = eq (r.ask "hostsIn" { env = "prod"; }) ([
        "lb"
        "lb-minimal"
        "web-1"
        "web-2"
      ]);
      t3 = yes (lib.elem "attic" (r.ask "aspectsOn" { host = "lb"; }));
      t4 = eq ((r.ask "hostsIn" { }).code) ("missing-param");
      t5 = eq (r.ask "errorsBy" { }) ([ ]);
    };
    agent-mcp-app = {
      t1 = eq (out.apps.x86_64-linux.yen-mcp.type) ("app");
      t2 = yes (lib.hasSuffix "/bin/yen-mcp" out.apps.x86_64-linux.yen-mcp.program);
    };
    agent-labels = {
      t1 = eq (r.labels.rdf-pack.trust) (1);
      t2 = eq (r.labels.attic.trust) (3);
      t3 = yes (
        lib.all (
          x:
          lib.elem x.aspect [
            "rdf-pack"
            "serving-explain"
            "retire-notice"
            "mcp-app"
          ]
        ) (r.floor 3)
      );
      t4 = eq (r.floor 1) ([ ]);
    };
    agent-valid-time = {
      t1 = yes (r.active.retire-notice.${web2});
      t2 = no (r.active.retire-notice.${web1});
    };
    agent-impact =
      let
        i = r.impact lb { hops = 1; };
      in
      {
        t1 = yes (lib.any (x: x.scope == P && x.depth == 1) i.reached);
        t2 = eq ((r.impact lb { sinks = [ "nixos" ]; }).reached) ([ ]);
      };
    agent-without =
      let
        files = lib.filter (f: lib.hasSuffix ".nix" (toString f) && !lib.hasPrefix "_" (baseNameOf f)) (
          lib.filesystem.listFilesRecursive ./modules
        );
        w = yen.without {
          inherit files;
          path = [
            "aspects"
            "attic"
          ];
          args = { inherit inputs lib; };
        };
      in
      {
        t1 = eq (map baseNameOf w.dropped) ([ "secrets.nix" ]);
        t2 = no ((w.result.active ? attic));
      };
    krn-fuel =
      let
        K = yen.krn;
        fives =
          x:
          K.disj [
            (K.eq x 5)
            (fives x)
          ];
        s = K.runAllFuel 40 (q: fives q);
      in
      {
        t1 = no (s.complete);
        t2 = yes (s.answers != [ ]);
        t3 = yes (lib.all (x: x == 5) s.answers);
      };
    agent-shacl =
      let
        t = yen.rdf.shacl r;
      in
      {
        t1 = yes (lib.hasInfix "sh:targetClass <https://yen.dev/fleet/kind/host>" t);
        t2 = yes (
          lib.hasInfix "<https://yen.dev/fleet/field/environment> ; sh:maxCount 1 ; sh:class <https://yen.dev/fleet/kind/environment>" t
        ); # a line of the pack, not a regex over 700 KB: `.*` regexes recurse per character and overflow the stack (nix 2.35)
        t3 = yes (
          lib.elem "<https://yen.dev/fleet/instance/environment/lab> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <https://yen.dev/fleet/kind/environment> ." (
            lib.splitString "\n" (yen.rdf.ntriples r)
          )
        );
      };
    # an agent's change between machines is refused BEFORE deploy, with the reason
    safety-db-cross-env =
      let
        s = yen.stage {
          base = fleet [ ];
          change =
            { yen, ... }:
            {
              yen.host.app-4.dbOn = yen.host.stage;
            };
        };
      in
      {
        t1 = no (s.ok);
        t2 = eq (s.violations) ([
          [
            "bad"
            "db-same-env"
            "fleet:main/environment:lab/host:app-4"
          ]
        ]);
        t3 =
          eq
            (r.check.whyNot [
              "bad"
              "db-same-env"
              "fleet:main/environment:lab/host:app-4"
            ])
            ([
              {
                rule = null;
                reason = "no rule has this head";
              }
            ]); # not even a candidate today
      };
    safety-addr-clash =
      let
        s = yen.stage {
          base = fleet [ ];
          change =
            { yen, ... }:
            {
              yen.host.rogue = {
                environment = yen.environment.lab;
                channel = yen.channel.stable;
                system = yen.system.x86_64-linux;
                addr = "10.0.1.1";
              };
            };
        };
      in
      {
        t1 = no (s.ok);
        t2 = eq (s.violations) ([
          [
            "bad"
            "unique-addr"
            "10.0.1.1"
          ]
        ]);
      };
    safety-trust-order =
      let
        s = yen.stage {
          base = fleet [ ];
          change =
            { yen, ... }:
            {
              yen.host.app-4.dependsOn = [ yen.host.stage ];
            };
        };
      in
      {
        t1 = no (s.ok);
        t2 = eq (s.violations) ([
          [
            "bad"
            "trust-order"
            "fleet:main/environment:lab/host:app-4"
            "fleet:main/environment:staging/host:stage"
          ]
        ]);
        t3 = eq ((yen.stage {
          base = fleet [ ];
          change =
            { yen, ... }:
            {
              yen.host.app-4.dependsOn = [ yen.host.lb ];
            };
        }).violations
        ) ([ ]);
      };
    synth-free-port =
      let
        a = r.ask "freePort" { host = "lb"; };
      in
      {
        t1 = eq (a.port) (8083);
        t2 = eq (lib.sort (x: y: x < y) a.used) ([
          8080
          8081
          8082
        ]);
        t3 = eq ((r.ask "freePort" { host = "web-1"; }).port) (8080);
      };
    synth-place-db = {
      t1 = eq (r.ask "placeDb" { host = "web-1"; }) ([ "lb" ]);
      t2 = eq (r.ask "placeDb" { host = "stage"; }) ([ "stage" ]);
    };
    synth-safe-hosts =
      eq
        (r.ask "safeHostsFor" {
          aspect = "attic";
          env = "staging";
        })
        ({
          safe = [ "stage" ];
          refused.studio = [
            [
              "bad"
              "attic"
              "fleet:main/environment:staging/mac:studio"
            ]
          ];
        });
    kits-install-order =
      let
        w = r.ask "installOrder" { assembly = "backup"; };
      in
      {
        t1 = eq (lib.head w) ([ "lb" ]);
        t2 = eq (lib.length w) (2);
        t3 = yes (lib.elem "web-1" (lib.elemAt w 1));
        t4 = no ((lib.elem "lb" (lib.elemAt w 1)));
      };
    kits-one-assembly-more = eq (osAt lb [
      "environment"
      "etc"
      "extra"
      "text"
    ]) ([ "svc-a" ]);
    kits-contract =
      let
        e = with' (
          { yen, ... }:
          {
            yen.assembly = {
              bad-role = {
                kit = yen.kit.sshd;
                roles.nope.at = yen.host.lb;
              };
              empty = {
                kit = yen.kit.sshd;
                roles = { };
              };
              backup2 = {
                kit = yen.kit.borg;
                roles.server.at = [
                  yen.host.lb
                  yen.host.web-1
                ];
              };
              banner2 = {
                kit = yen.kit.banner;
                roles.default.at = yen.host.lb;
              };
              nouser = {
                kit = yen.kit.users;
                roles.default.at = yen.host.web-1;
              };
              badtype = {
                kit = yen.kit.users;
                roles.default = {
                  at = yen.host.web-1;
                  settings.user = 42;
                };
              };
              by-name = {
                kit = yen.kit.sshd;
                roles.server.at = "lb";
              };
            };
          }
        );
      in
      yes (
        lib.all (hasMsg e) [
          ".*assembly bad-role: kit sshd has no role nope.*"
          ".*assembly empty has no roles.*"
          ".*backup2 role server: 2 machines, at most 1.*"
          ".*kit banner allows 1 assemblies.*"
          ".*by-name role server: `at` is a string, not a predicate.*"
          ".*nouser.default: setting user is not a string.*"
          ".*badtype.default: setting user is not a string.*"
        ]
      );
    vars-generators = {
      t1 = eq (noApps (lib.sort (a: b: a < b) (lib.attrNames (red "generators" "fleet:main")))) ([
        "borg-backup@lb"
        "borg-backup@lb-minimal"
        "borg-backup@stage"
        "borg-backup@web-1"
        "borg-backup@web-2"
        "from-exports@web-1"
        "openssh@lb"
        "openssh@lb-minimal"
        "openssh@stage"
        "openssh@studio"
        "openssh@web-1"
        "openssh@web-2"
        "wifi.home"
      ]);
      t2 = yes (
        hasMsg (with' (
          { yen, ... }:
          {
            yen.aspects.dep-bad = {
              at = yen.host.web-1;
              generators =
                { scope, ... }:
                {
                  name = "x";
                  dependencies = [ "missing" ];
                };
            };
          }
        )) ".*x@web-1 depends on missing, which web-1 has not.*"
      );
    };
    vars-public-value = {
      t1 = eq (osAt lb [
        "environment"
        "etc"
        "ssh/host-key.pub"
        "text"
      ]) ([ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFleetTestKeyNotReal lb" ]);
      t2 = eq (osAt web1 [
        "environment"
        "etc"
        "ssh/host-key.pub"
        "text"
      ]) ([ "absent" ]);
    };
    vars-autoinclude = {
      t1 = yes (
        lib.any (m: lib.isAttrs m && lib.elem ./machines/web-2/configuration.nix (m.imports or [ ])) (
          list (red "nixos" web2)
        )
      );
      t2 = no (r.active.autoinclude.${web1});
    };
    hoag-claims-reverse-read = {
      t1 =
        eq
          (first (
            nixosAt lb [
              "services"
              "postgresql"
              "ensureDatabases"
            ]
          ))
          ([
            "app_web_1"
            "app_web_2"
          ]);
      t2 = eq (first (
        nixosAt stage [
          "services"
          "postgresql"
          "ensureDatabases"
        ]
      )) ([ "app_stage" ]);
      t3 = eq (first (
        nixosAt web1 [
          "services"
          "postgresql"
          "ensureDatabases"
        ]
      )) (null);
      t4 = eq (first (
        nixosAt web1 [
          "environment"
          "etc"
          "app/database-url"
          "text"
        ]
      )) ("postgres://10.0.1.1/app_web_1");
    };
    hoag-collectors = {
      t1 = eq (lib.attrNames out.colmenaHives.prod) ([
        "lb"
        "meta"
        "web-1"
        "web-2"
      ]);
      t2 = eq (lib.attrNames out.colmenaHives.staging) ([
        "meta"
        "stage"
      ]);
      t3 = yes (out.colmenaHives.staging.meta.allowApplyAll);
    };
    hoag-query-layers = {
      t1 = eq (map noApps out.deployWaves) ([
        [ "lb" ]
        [
          "web-1"
          "web-2"
        ]
        [ "stage" ]
      ]);
      t2 = eq (out.dependents.lb) ([
        "web-1"
        "web-2"
      ]);
      t3 = eq (out.dependents.stage) ([ ]);
    };
  };

  e2e = rec {
    lbCfg = out.nixosConfigurations.lb.config;
    checks = {
      lb-toplevel = yes (lib.hasSuffix ".drv" lbCfg.system.build.toplevel.drvPath);
      # every CI target evaluates to a derivation (assertions included): the darwin system too
      studio-toplevel =
        let
          x = builtins.tryEval out.darwinConfigurations.studio.config.system.build.toplevel.drvPath;
        in
        {
          t1 = yes (x.success);
          t2 = yes (lib.hasSuffix ".drv" x.value); # a failed assertion is a throw: named red
        };
      # trimmed base module lists: the same toplevel as the full list; a list without nginx fails for a host that sets it
      modlist-same-drv =
        let
          d = c: c.config.system.build.toplevel.drvPath;
        in
        {
          t1 = eq (lib.attrNames out.nixosConfigurationsFull) ([
            "app-2"
            "web-1"
          ]);
          t2 = yes (
            lib.all (n: d out.nixosConfigurations.${n} == d out.nixosConfigurationsFull.${n}) [
              "app-2"
              "web-1"
            ]
          );
        };
      modlist-negative =
        let
          np = inputs.nixpkgs;
          all = import "${np}/nixos/modules/module-list.nix";
          keep = lib.genAttrs (map (
            p: builtins.unsafeDiscardStringContext "${np}/nixos/modules/${p}"
          ) (import ./modules/platforms/_modlists.nix).checked.web-1) (_: true);
          pick =
            dropNginx:
            lib.filter (
              p:
              !(builtins.isPath p)
              || (
                keep ? ${builtins.unsafeDiscardStringContext (toString p)}
                && !(dropNginx && lib.hasInfix "web-servers/nginx/default.nix" (toString p))
              )
            ) all;
          sys =
            dropNginx:
            np.lib.nixosSystem {
              system = "x86_64-linux";
              baseModules = pick dropNginx;
              modules = list (red "nixos" web1);
            };
        in
        {
          t1 = no ((builtins.tryEval (sys true).config.system.build.toplevel.drvPath).success);
          t2 = yes ((builtins.tryEval (sys false).config.system.build.toplevel.drvPath).success); # the same list with nginx builds
        };
      shared-pkgs-same-drv =
        let
          d = c: c.config.system.build.toplevel.drvPath;
        in
        # every follower: its toplevel on the shared pkgs equals its toplevel on its own pkgs
        {
          followers = yes (
            lib.all (n: out.sharedPkgs.${n}.follower) (lib.attrNames out.nixosConfigurationsOwnPkgs)
          );
          # lb-minimal: lb's variant inherits sharedPkgs
          own-pkgs = eq (lib.attrNames out.nixosConfigurationsOwnPkgs) [
            "app-2"
            "app-3"
            "lb"
            "lb-minimal"
            "web-1"
            "web-2"
          ];
          leader = eq out.sharedPkgs.lb.leader "app-1";
          same-drv = yes (
            lib.all (n: d out.nixosConfigurations.${n} == d out.nixosConfigurationsOwnPkgs.${n}) (
              lib.attrNames out.nixosConfigurationsOwnPkgs
            )
          );
          no-app-4 = no (out.sharedPkgs ? app-4);
          no-stage = no (out.sharedPkgs ? stage);
        };
      kits-built = {
        t1 = eq (lbCfg.services.borgbackup.jobs.backup.repo) ("borg@10.0.1.1:/srv/lb");
        t2 = yes (lbCfg.users.users ? svc-a);
        t3 = yes (lbCfg.users.users ? svc-b);
        t4 = yes (lbCfg.services.openssh.enable);
        t5 = eq (lbCfg.environment.etc.extra.text) ("svc-a");
        t6 = eq (out.nixosConfigurations.web-2.config.environment.etc.autoinclude.text) ("web-2");
        t7 = eq (out.nixosConfigurations.stage.config.environment.etc."wifi/networks".text) ("home office");
        t8 = eq (out.darwinConfigurations.studio.config.environment.etc.banner.text) ("managed by yen");
      };
      lb-haproxy-order = yes (
        lib.hasInfix "10.0.1.10:80 check\n  server 10.0.1.11" lbCfg.services.haproxy.config
      );
      lb-motd = {
        t1 = eq (lbCfg.environment.etc.motd.text) ("managed by yen");
        t2 = eq (lbCfg.networking.hostName) ("lb");
      };
      lb-overlay = eq (lib.length lbCfg.nixpkgs.overlays) (1);
      lb-flatten-class-lib = {
        t1 = eq (lbCfg.users.users.alice.description) ("Alice");
        t2 = yes (lbCfg.users.users.alice.isNormalUser);
      };
      lb-hm-alice = {
        t1 = yes (lbCfg.home-manager.users.alice.programs.git.enable);
        t2 = yes (lbCfg.home-manager.users.alice.services.ssh-agent.enable);
      };
      lb-age-manifest = {
        t1 = eq (out.ageManifest.lb) ([ "attic-env" ]);
        t2 = eq (lbCfg.age.secrets.attic-env.path) ("/run/agenix/lb-attic");
      };
      lb-specialisation = yes (lbCfg.specialisation ? debug);
      lb-no-gui-passes = eq (out.checks.x86_64-linux.lb-no-gui.drvAttrs.buildCommand) ("touch $out");
      lb-no-gui-firefox-fails = yes (
        lib.hasInfix "exit 1"
          (with' (
            {
              pkgs ? null,
              ...
            }:
            {
              yen.aspects.firefox = {
                at = {
                  kind = "host";
                  name = "lb";
                };
                nixos =
                  { pkgs, ... }:
                  {
                    environment.systemPackages = [ pkgs.firefox ];
                  };
              };
            }
          )).flake.checks.x86_64-linux.lb-no-gui.drvAttrs.buildCommand
      );
      studio-darwin =
        let
          c = out.darwinConfigurations.studio.config;
        in
        {
          t1 = yes (c.system.defaults.dock.autohide);
          t2 = eq (c.networking.hostName) ("studio");
          t3 = yes (c.home-manager.users.bob.programs.aerospace.enable);
        };
      home-edge =
        let
          c = out.homeConfigurations.alice-laptop.config;
        in
        {
          t1 = yes (c.programs.git.enable);
          t2 = no (c.services.ssh-agent.enable);
          t3 = eq (c.home.username) ("alice");
        };
      den-739-standalone-home =
        eq (out.homeConfigurations."alice@stage".config.home.sessionVariables.MONITORRES)
          ("2560x1440");
      infra-lb-passes = eq (out.checks.x86_64-linux.infra-lb.drvAttrs.buildCommand) ("touch $out");
      infra-lb-drift-fails = yes (
        lib.hasInfix "networking.hostName"
          (with' {
            yen.aspects.drift = {
              at = {
                kind = "host";
                name = "lb";
              };
              nixos =
                { lib, ... }:
                {
                  networking.hostName = lib.mkForce "drifted";
                };
            };
          }).flake.checks.x86_64-linux.infra-lb.drvAttrs.buildCommand
      );
      den-enrichment-built = {
        t1 = eq (lbCfg.environment.variables.PLATFORM) ("linux");
        t2 = yes (lib.hasInfix "bob@stage" lbCfg.environment.etc.peers.text);
        t3 = yes (lib.elem 80 lbCfg.networking.firewall.allowedTCPPorts);
        t4 = no ((lib.elem 53 lbCfg.networking.firewall.allowedTCPPorts)); # 2200 is ssh-port
      };
      den-producer-own-config-built =
        eq (out.homeConfigurations."alice@stage".config.home.sessionVariables.HOST_DESKTOP)
          ("yes");
      hoag-class-share-gate = {
        t1 = yes (out.classShare.nixos.members.lb.gate);
        t2 = yes (out.classShare.nixos.coreSize > 0);
        t3 = yes (out.classShare.nixos.members.lb.deltaSize < out.classShare.nixos.members.lb.fullSize);
      };
      hoag-class-share-tampered-core-fails =
        let
          cs = out.classShare.nixos;
          bad = inputs.nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              { imports = cs.core ++ [ { networking.domain = "tampered"; } ]; }
            ]
            ++ cs.members.lb.delta;
          };
        in
        yes (bad.config.system.build.toplevel.drvPath != lbCfg.system.build.toplevel.drvPath);
      den-713-home-reads-host-config =
        eq (out.homeConfigurations."alice@stage".config.home.sessionVariables.HOST_DESKTOP)
          ("yes");
      # osConfig sink: a nested user and a standalone home under a host read the host's config; pkgs is home-manager's
      os-config-nested = {
        t1 = eq (lbCfg.home-manager.users.alice.home.sessionVariables.EDITOR_HOST) ("lb");
        t2 = yes (lib.any (p: lib.getName p == "nano") lbCfg.home-manager.users.alice.home.packages);
      };
      os-config-standalone =
        let
          c = out.homeConfigurations."alice@stage".config;
        in
        {
          t1 = eq (c.home.sessionVariables.EDITOR_HOST) ("stage");
          t2 = yes (lib.any (p: lib.getName p == "nano") c.home.packages);
        };
      hoag-claims-built = yes (
        lib.elem "app_web_1" out.nixosConfigurations.lb.config.services.postgresql.ensureDatabases
      );
      den-chained-forward-built = eq (out.nixosConfigurations.lb.config.home-manager.users.alice.programs.git.extraConfig.init.defaultBranch) (
        "main"
      ); # lb: stable channel, HM 25.05
      lb-minimal-built = {
        t1 = yes (
          lib.hasSuffix ".drv" out.nixosConfigurations.lb-minimal.config.system.build.toplevel.drvPath
        );
        t2 = no (out.nixosConfigurations.lb-minimal.config.services.haproxy.enable);
      };
      export-module = eq ((inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          out.nixosModules.base
          {
            boot.loader.grub.device = "nodev";
            fileSystems."/".device = "x";
            system.stateVersion = "25.05";
          }
        ];
      }).config.environment.etc.motd.text
      ) ("managed by yen");
    };
  };
in
{
  inherit
    checks
    e2e
    r
    with'
    ;
  # the suites, for github:denful/fastest: tests.<suite>.<test> = { expr; expected; }
  tests = {
    fleet = checks;
    e2e = e2e.checks;
  };
}
