# Fleet oracles: one check per row of Ren's expected-results table, sini's patterns and Den's.
# Run: nix eval --offline --impure --file tests.nix failed        (expect [ ])
#      nix eval --offline --impure --file tests.nix e2e.failed    (real NixOS / darwin / home-manager evals)
let
  inputs = (builtins.getFlake "path:${toString ../..}?dir=templates/fleet").inputs;
  inherit (inputs.nixpkgs) lib;
  sven = inputs.sven.lib;
  b = builtins;
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
    _module.args = { inherit inputs lib; };
  };
  r = sven.eval (fleet [ ]);
  with' = m: sven.eval (fleet [ m ]);
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
    no-errors = msgs r == [ ];
    docs-mermaid = lib.hasInfix "-->|nixos|" out.docs.mermaid && edge "nixos" ci stage;
    fold-one = out.deploy.nodes.lb.hostname == "10.0.1.1";
    fold-one-two-emitters = hasMsg (with' (
      { sven, ... }:
      {
        sven.aspects.deploy2 = {
          at = sven.host.lb;
          deploy = {
            address = "x";
            user = "y";
          };
        };
      }
    )) "one: got 2 elements";
    fold-list-order =
      red "backends" P == [
        "10.0.1.10"
        "10.0.1.11"
      ];
    guest-channel-stable = (scope ci).channel.name == "stable" && (scope stage).channel.name == "edge";
    guest-pkgs-stable =
      (first (
        nixosAt stage [
          "microvm"
          "vms"
          "ci"
          "pkgs"
        ]
      )).path == inputs.nixpkgs.legacyPackages.x86_64-linux.path;
    chained-forward =
      edge "os" "${ci}/user:bob" ci
      && edge "nixos" ci stage
      && !(lib.any (u: u ? bob) (
        nixosAt stage [
          "home-manager"
          "users"
        ]
      ));
    darwin-not-nixos =
      out ? darwinConfigurations.studio
      && !(out.nixosConfigurations ? studio)
      && !(out.nixosConfigurations ? ci);
    kernel-not-on-studio = !r.active.kernel.${studio} && r.active.kernel.${lb};
    ssh-agent-not-standalone =
      !r.active.ssh-agent."${laptop}/user:alice" && r.active.ssh-agent."${lb}/user:alice";
    host-qualified-htop = on "htop" == [ "${web1}/user:alice" ];
    substitute-web2 = !r.active.motd.${web2} && r.active.motd-short.${web2} && r.active.motd.${web1};
    has-docker =
      lib.sort (a: b: a < b) (on "docker") == [
        stage
        ci
      ];
    parent-devices =
      names (
        hmAt "${lb}/user:alice" [
          "services"
          "syncthing"
          "settings"
          "devices"
        ]
      ) == [
        "alice-laptop"
        "alice@stage"
        "ci"
        "lb-minimal"
        "pixel"
        "stage"
        "studio"
        "web-1"
        "web-2"
      ];
    per-system =
      lib.attrNames out.packages == [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ]
      && lib.all (p: p ? hello) (lib.attrValues out.packages);
    overlays-once = lib.length (red "overlays" "fleet:main") == 1;
    persist-stage =
      lib.sort (a: b: a < b) (red "persist" stage) == [
        "/home/alice/.local/state/syncthing"
        "/home/bob/.local/state/syncthing"
        "/var/lib/docker"
        "/var/lib/nginx"
      ];
    persist-ci-own = lib.elem "/var/lib/docker" (red "persist" ci);
    output-merge-equal =
      msgs (
        with' (
          { sven, ... }:
          {
            sven.aspects.same-hello = {
              at = sven.system.x86_64-linux;
              packages.greeting = "hi";
            };
            sven.aspects.same-hello2 = {
              at = sven.system.x86_64-linux;
              packages.greeting = "hi";
            };
          }
        )
      ) == [ ];
    output-merge-conflict = hasMsg (with' (
      { sven, ... }:
      {
        sven.aspects.c1 = {
          at = sven.system.x86_64-linux;
          packages.greeting = "a";
        };
        sven.aspects.c2 = {
          at = sven.system.x86_64-linux;
          packages.greeting = "b";
        };
      }
    )) "merge conflict at greeting";
    bare-overlay-refused = hasMsg (with' (
      { sven, ... }:
      {
        sven.aspects.bare = {
          at = sven.fleet.main;
          overlays = final: prev: { };
        };
      }
    )) ".*bare function.*";
    home-darwin-only-studio =
      lib.attrNames r.reduced.homeDarwin == [
        "${studio}/user:alice"
        "${studio}/user:bob"
      ];
    tags-stage-web = lib.elem "web" (red "tags" stage);
    flake-file-inputs =
      lib.attrNames (red "flake-file" "fleet:main").inputs == lib.attrNames (import ./flake.nix).inputs; # the generated flake.nix has exactly the declared inputs
    flake-file-conflict = hasMsg (with' (
      { sven, ... }:
      {
        sven.aspects.agenix2 = {
          at = sven.fleet.main;
          flake-file.inputs.agenix.url = "github:other/agenix";
        };
      }
    )) "merge conflict at inputs.agenix.url";
    recursive-attrs-deploy =
      noApps (lib.attrNames out.deploy.nodes) == [
        "lb"
        "lb-minimal"
        "stage"
        "web-1"
        "web-2"
      ];
    recursive-attrs-colmena =
      noApps (lib.attrNames r.reduced.colmena."fleet:main") == [
        "lb"
        "lb-minimal"
        "stage"
        "web-1"
        "web-2"
      ];
    root-emission =
      (red "flake-file" "fleet:main").inputs.nixpkgs.url == "github:nixos/nixpkgs/nixos-25.05";
    spawn-pixel-only-alice =
      lib.filter (s: s.parent != null && s.parent.id == "${S}/phone:pixel") r.scopes != [ ]
      &&
        map (s: s.name) (lib.filter (s: s.parent != null && s.parent.id == "${S}/phone:pixel") r.scopes)
        == [ "alice" ];
    spawn-lb-only-alice =
      map (s: s.name) (lib.filter (s: s.parent != null && s.parent.id == lb && s.kind == "user") r.scopes)
      == [ "alice" ];
    data-kinds-no-scopes =
      !(lib.any (
        s:
        lib.elem s.kind [
          "group"
          "machine"
          "channel"
          "db"
          "region"
        ]
      ) r.scopes);
    tray-stage-not-lb =
      hmAt "${stage}/user:alice" [
        "services"
        "syncthing"
        "tray"
        "enable"
      ] == [ true ]
      &&
        hmAt "${lb}/user:alice" [
          "services"
          "syncthing"
          "tray"
          "enable"
        ] == [ false ];
    into-outputs =
      out ? colmenaHive && out ? ageManifest && out ? packages && out ? terraformConfigurations;
    inventory-json = (scope web1) != null && (scope web2).buildHost == "10.0.1.1";
    inventory-string-ref-refused = hasMsg (with' {
      sven.host.bad = {
        environment = "prod";
        addr = "x";
      };
    }) ".*environment wants a environment ref.*";
    vars =
      out.vars.shared.ca.files == [
        "ca.crt"
        "ca.key"
      ]
      &&
        noApps (lib.attrNames out.vars.per-machine) == [
          "lb"
          "lb-minimal"
          "stage"
          "web-1"
          "web-2"
        ];
    checks-names =
      noApps (lib.attrNames out.checks.x86_64-linux) == [
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
      ]
      && !(out.checks.x86_64-linux ? web)
      && out.vmTests.x86_64-linux ? web
      && !(out.vmTests ? aarch64-linux)
      && out.checks.aarch64-linux ? pre-commit;
    buildhost =
      (red "deploy" web2).buildHost == "10.0.1.1"
      && (red "deploy" lb).buildHost == null
      && red "deploy" ci == null;
    facter-metal =
      noApps (on "facter") == [
        lb
        "${lb}/host:lb-minimal"
        web1
        web2
        stage
      ];
    typed-scrape =
      red "scrape" "fleet:main" == [
        {
          job = "r1";
          target = "eu.eu:9090";
        }
      ];
    typed-scrape-bad = hasMsg (with' (
      { sven, ... }:
      {
        sven.aspects.bad-scrape = {
          at = sven.host.lb;
          scrape.job = 1;
        };
      }
    )) ".*fails `of`.*";
    diamond-nginx-once =
      lib.length (
        nixosAt web1 [
          "services"
          "nginx"
          "enable"
        ]
      ) == 1
      &&
        lib.length (
          nixosAt stage [
            "services"
            "nginx"
            "enable"
          ]
        ) == 1;
    merge-across-files =
      r.active.base.${lb}
      &&
        noApps (lib.attrNames (red "records" "fleet:main")) == [
          "ci"
          "lb"
          "lb-minimal"
          "stage"
          "studio"
          "web-1"
          "web-2"
        ];
    recursive-kinds =
      scope "fleet:main/domain:example.org/domain:api.example.org/domain:v1.api.example.org" != null;
    twice-on-path = hasMsg (with' (
      { sven, ... }:
      {
        sven.kinds.fleet.spawns.ring = _: { r = { }; };
        sven.kinds.ring.spawns.ring = s: { r = { }; };
      }
    )) ".*instance ring:r twice on path.*";
    nearest-bob-ci =
      (upTo [ "host" "guest" "mac" ] (scope "${ci}/user:bob")).id == ci
      && (upTo [ "environment" ] (scope "${ci}/user:bob")).name == "staging"
      && upTo [ "environment" ] (scope "fleet:main") == null;
    graph-query = lib.length r.graph.scopes == lib.length r.scopes;

    # ── sini ──
    k3s-cluster-only =
      lib.sort (a: b: a < b) (on "k3s") == [
        web1
        web2
      ];
    k3s-discovery =
      out.k8sManifests.axon.applications.k3s.nodes == [
        "10.0.1.10"
        "10.0.1.11"
      ]
      && out.k8sManifests.axon.target.branch == "main";
    k3s-bootstrap =
      nixosAt web1 [
        "services"
        "k3s"
        "clusterInit"
      ] == [ true ]
      &&
        nixosAt web1 [
          "services"
          "k3s"
          "serverAddr"
        ] == [ ]
      &&
        nixosAt web2 [
          "services"
          "k3s"
          "serverAddr"
        ] == [ "https://10.0.1.10:6443" ];
    acl-sso-only =
      red "idm-users" P == [ "dana" ] && !lib.any (s: s.kind == "user" && s.name == "dana") r.scopes;
    acl-host-grants =
      scope "${web2}/user:bob" == null
      &&
        lib.any (s: s.id == "${web2}/user:bob")
          (with' (
            { sven, ... }:
            {
              sven.host.web-2.grants = [ sven.group.deploy ];
            }
          )).scopes;
    acl-host-gates =
      scope "${lb}/user:alice" != null
      && !lib.any (s: s.id == "${lb}/user:alice")
        (with' (
          { sven, ... }:
          {
            sven.host.lb.gates = [ sven.group.deploy ];
          }
        )).scopes;
    inference-allow =
      nixosAt lb [
        "environment"
        "etc"
        "inference/allow"
        "text"
      ] == [ "10.0.1.10\n10.0.2.10\n" ];
    inference-no-address = hasMsg (with' (
      { sven, ... }:
      {
        sven.host.web-2.settings.inference.clients = [ "ghost" ];
      }
    )) ".*client ghost has no address.*";
    guard-named-host = out.k8sManifests.axon.applications.guard.hub == "alice@lb";
    join-upstreams = out.k8sManifests.axon.applications.gateway.listeners == [ "web-1.example.org" ];
    join-env-scoped =
      (with' (
        { sven, ... }:
        {
          sven.aspects.stage-up = {
            at = sven.host.stage;
            served-domains = [ "stage.example.org" ];
            gateway-upstreams = {
              address = "10.0.2.10";
              exclude = [ ];
            };
          };
        }
      )).flake.k8sManifests.axon.applications.gateway.listeners == [ "web-1.example.org" ];
    guest-intent-parent =
      nixosAt stage [
        "environment"
        "etc"
        "vfio/ids"
        "text"
      ] == [ "10de:2203" ]
      && !r.active.vfio.${lb}
      && (
        let
          r2 = with' (
            { sven, ... }:
            {
              sven.guest.gpu = {
                environment = sven.environment.prod;
                channel = sven.channel.stable;
                system = sven.system.x86_64-linux;
                addr = "10.0.1.30";
                on = sven.host.lb;
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
      );
    factories =
      map (z: "${z.account}:${z.zone}") (red "dns-zones" "fleet:main") == [
        "api:api.example.org"
        "json64:example.org"
      ]
      ||
        map (z: "${z.account}:${z.zone}") (red "dns-zones" "fleet:main") == [
          "json64:example.org"
          "api:api.example.org"
        ];
    unit-check-stand-in =
      out.checks.x86_64-linux ? guard-pod && red "unit-checks" "fleet:main" == { guard-pod = true; };
    one-edge = hasMsg (with' (
      { sven, ... }:
      {
        sven.environment.staging.dns.publicIPv4 = "198.51.100.1";
      }
    )) "dns: 2 environments set dns.publicIPv4.*";
    ingest-across-envs =
      nixosAt web1 [
        "environment"
        "etc"
        "alloy/endpoints"
        "text"
      ] == [ "https://ingest.example.org\n" ]
      &&
        nixosAt stage [
          "environment"
          "etc"
          "alloy/endpoints"
          "text"
        ] == [ "" ];
    domains-records =
      map (e: e.value.name) (red "dns-records" "fleet:main") == [ "example.org" ]
      && lib.length (red "certificate-domains" "fleet:main") == 3;
    terranix-conditional =
      out ? terranixConfigurations.dns-prod && !(out.terranixConfigurations ? dns-staging);
    unifi-forwards = out.unifiTerranixModules.prod != [ ] && lib.length (red "port-forwards" P) == 1;
    home-linux =
      r.reduced.homeLinux ? "${lb}/user:alice"
      && !(r.reduced.homeLinux ? "${studio}/user:alice")
      && !(r.reduced.homeLinux ? "${laptop}/user:alice");
    primary-user =
      on "primary-user" == [
        "${lb}/host:lb-minimal/user:alice"
        "${lb}/user:alice"
      ];
    syncthing-hub =
      on "syncthing-hub" == [ stage ]
      &&
        names (
          nixosAt stage [
            "services"
            "syncthing"
            "settings"
            "folders"
          ]
        ) == [
          "alice-home"
          "bob-home"
        ];
    syncthing-peers =
      first (
        hmAt "${lb}/user:alice" [
          "home"
          "file"
          ".syncthing-peers"
          "text"
        ]
      ) == builtins.toJSON [
        "lb-minimal"
        "web-1"
        "web-2"
        "ci"
        "alice@stage"
        "stage"
      ]; # scope order: guest:ci and home:alice@stage sort before user:alice
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
      !(lib.elem "/var/lib/nginx" (d web2))
      && lib.elem "/var/lib/nginx" (d web1)
      && lib.elem "/var/lib/nginx" (red "persist" web2);
    tags-from-roles =
      r.reduced.colmena."fleet:main".stage.deployment.tags == [
        "staging"
        "web"
        "workstation"
        "laptop"
      ]
      &&
        r.reduced.colmena."fleet:main".lb.deployment.tags == [
          "prod"
          "server"
        ];
    profile-not-guests =
      r.active.desktop.${stage} && !r.active.desktop.${ci} && r.active.thermald.${stage};
    unfree-set = red "unfree" stage == [ "terraform" ];
    xmsg-trust =
      hmAt "${lb}/user:alice" [
        "home"
        "file"
        ".xmsg-peers"
        "text"
      ] == [ (builtins.toJSON [ "bob" ]) ];
    flake-level =
      out ? devShells.x86_64-linux.default
      && out ? formatter.x86_64-linux
      && out.packages.x86_64-linux ? greet
      && out.packages.x86_64-linux ? k8s-all
      && out ? overlays.default;
    settings-cascade =
      nixosAt web1 [
        "boot"
        "kernelParams"
      ] == [ [ "zfs.zfs_arc_max=8589934592" ] ]
      &&
        nixosAt stage [
          "boot"
          "kernelParams"
        ] == [ [ "zfs.zfs_arc_max=4294967296" ] ]
      &&
        nixosAt lb [
          "boot"
          "kernelParams"
        ] == [ [ "zfs.zfs_arc_max=4294967296" ] ];
    relation-kind = scope "fleet:main/replica:r1" != null && scope "fleet:main/replica:r2" == null;

    # ── Den ──
    den-specialisation =
      edge "nixos" "${lb}/variant:debug" lb
      &&
        nixosAt lb [
          "specialisation"
          "debug"
          "configuration"
          "imports"
        ] != [ ];
    den-ids =
      nixosAt lb [
        "services"
        "openssh"
        "ports"
      ] == [ [ 2204 ] ]
      &&
        nixosAt web2 [
          "services"
          "openssh"
          "ports"
        ] == [ [ 2208 ] ]; # app-1..4 sort first
    den-module-outside = lib.isList (red "nixos" lb) && lib.length (red "nixos" lb) > 10; # moduleOf: a query gives the module list
    den-nested-groups =
      lib.length (lib.filter (s: s.kind == "user" && s.name == "alice") r.scopes) == 10;
    den-739-home-on-host =
      edge "homeManager" "${stage}/home:alice@stage/user:alice" "${stage}/home:alice@stage"
      &&
        hmAt "${stage}/home:alice@stage" [
          "home"
          "sessionVariables"
          "MONITORRES"
        ] == [ "2560x1440" ]
      &&
        hmAt "${stage}/user:alice" [
          "home"
          "sessionVariables"
          "MONITORRES"
        ] == [ ];
    den-739-not-in-host-hm = !(edge "os" "${stage}/home:alice@stage/user:alice" stage);

    # ── swarsel ──
    swarsel-variant =
      scope "${lb}/host:lb-minimal" != null
      && !r.active.haproxy."${lb}/host:lb-minimal"
      && out.nixosConfigurations ? lb-minimal;
    swarsel-nodes =
      let
        xs = id: map (m: m.networking.extraHosts or null) (lib.concatLists (nixosAt id [ "imports" ]));
      in
      lib.elem "10.0.1.1 lb.internal" (xs web1) && !(lib.elem "10.0.1.1 lb.internal" (xs stage));
    swarsel-globals =
      (first (
        nixosAt lb [
          "networking"
          "hosts"
        ]
      )).${"10.0.1.10"} == [ "web-1.fleet" ];
    swarsel-export = lib.length out.nixosModules.base.imports == 2;

    # ── sini mesh, adda, vix ──
    sini-mesh-peers =
      map (p: p.endpoint) (
        first (
          nixosAt web1 [
            "networking"
            "wireguard"
            "interfaces"
            "mesh"
            "peers"
          ]
        )
      ) == [
        "10.0.1.1:51820"
        "10.0.1.11:51820"
      ];
    sini-nix-builders =
      first (
        nixosAt lb [
          "nix"
          "buildMachines"
        ]
      ) == [
        {
          hostName = "10.0.1.10";
          system = "x86_64-linux";
        }
      ]
      &&
        first (
          nixosAt web1 [
            "nix"
            "buildMachines"
          ]
        ) == [ ];
    adda-caddy =
      names (
        nixosAt lb [
          "services"
          "caddy"
          "virtualHosts"
        ]
      ) == [
        "grafana.example.org"
        "status.example.org"
      ];
    adda-templates = out.templates.default.description == "A sven fleet";
    vix-vim-features =
      red "vimrc" "${"fleet:main/system:x86_64-linux"}/vim:dev" == [
        "vim.o.number = true"
        "require('gitsigns').setup()"
        "vim.lsp.enable('nixd')"
        "vim.cmd.colorscheme('tokyonight')"
      ]
      && red "vimrc" "fleet:main/system:x86_64-linux/vim:min" == [ "vim.o.number = true" ]
      && out.packages.x86_64-linux ? vim-dev
      && lib.hasInfix "vim.lsp.enable" out.packages.x86_64-linux.vim-dev.text; # the package text: the arg reads the sink, not the kind
    vix-secrets =
      map (s: s.name) (red "secrets" "${stage}/user:bob") == [
        "gh-token"
        "gpg-key"
      ]
      && map (s: s.name) (red "secrets" "${lb}/user:alice") == [ "gh-token" ];

    # ── checks derived from the infra ──
    ci-matrix =
      noApps (map (j: j.name) out.ci.matrix) == [
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
      ];
    infra-facts =
      lib.attrNames (red "infra" "fleet:main").lb == [
        "hostname"
        "persist /home/alice/.local/state/syncthing"
      ]
      &&
        lib.attrNames (red "infra" "fleet:main").web-1 == [
          "hostname"
          "nginx"
          "persist /home/alice/.local/state/syncthing"
          "persist /var/lib/nginx"
          "port80"
        ];

    # ── Den CI capabilities (templates/ci/modules) ──
    den-batteries =
      osAt stage [
        "services"
        "getty"
        "autologinUser"
      ] == [ ]
      &&
        osAt ci [
          "services"
          "getty"
          "autologinUser"
        ] == [ "bob" ]
      &&
        osAt stage [
          "nixpkgs"
          "config"
          "permittedInsecurePackages"
        ] == [ [ "olm-3.2.16" ] ]
      && r.active.global-pkgs.${lb}
      && !r.active.global-pkgs."fleet:main/environment:prod/cluster:axon";
    den-chained-forward =
      edge "git" "${lb}/user:alice" "${lb}/user:alice"
      && gave "sink git" "homeManager" "${lb}/user:alice"
      && gave "sink homeManager" "os" lb;
    den-custom-class-no-hm =
      gave "sink maid" "os" "${stage}/user:bob" == false
      && gave "sink maid" "os" stage
      && !(gave "sink maid" "os" lb)
      && !(gave "sink maid" "os" studio); # maid: linux only, never darwin
    den-609-host-hm-no-leak =
      msgs (
        with' (
          { sven, ... }:
          {
            sven.aspects.host-hm = {
              at = sven.host.lb;
              homeManager.programs.htop.enable = true;
            };
          }
        )
      ) == [ ]
      && !(lib.any (e: e.origin == "aspect host-hm")
        (with' (
          { sven, ... }:
          {
            sven.aspects.host-hm = {
              at = sven.host.lb;
              homeManager.programs.htop.enable = true;
            };
          }
        )).graph.edges
      );
    den-projected-has-aspect =
      gave "aspect dev" "os" lb
      && gave "aspect dev" "homeManager" "${lb}/user:alice"
      && !(gave "aspect desktop" "nixos" ci);
    den-525-structure-from-presence =
      map (s: s.id) (lib.filter (s: s.kind == "backup") r.scopes) == [
        "${lb}/backup:nightly"
        "${web1}/backup:nightly"
        "${web2}/backup:nightly"
      ]
      &&
        nixosAt lb [
          "services"
          "restic"
          "backups"
          "nightly"
          "paths"
        ] == [
          [
            "/persist"
            "/etc/lb"
          ]
        ];
    den-instance-side-include = r.active.desktop.${stage} && r.active.motd."fleet:main/export:base";
    den-permutation-stable =
      let
        rev = sven.eval {
          imports = lib.reverseList (import ./_modules-list.nix);
          _module.args = { inherit inputs lib; };
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
      j rev == j r && map (s: s.id) rev.scopes == map (s: s.id) r.scopes;
    den-sibling-laziness =
      let
        p = with' (
          { sven, ... }:
          {
            sven.aspects.poison = {
              at = sven.host.web-2;
              nixos = throw "poisoned web-2";
            };
          }
        );
      in
      lib.length p.reduced.nixos.${lb} > 0
      && !(builtins.tryEval (builtins.deepSeq p.reduced.nixos.${web2} true)).success;

    # ── Den CI usage patterns (vic/den-patterns.md) ──
    den-cartesian-and-transitive =
      lib.sort (a: b: a < b) (red "pairs" stage) == [
        "alice-fido"
        "alice-rex"
        "bob-fido"
        "bob-rex"
        "rex/ball"
        "rex/bone"
      ]
      && red "pairs" lb == null;
    den-user-classes = gave "sink maid" "os" stage && !(r.reduced.maid ? "${stage}/user:alice");
    den-enrichment-sinks =
      red "isNixos" lb == true
      && red "platform" lb == "linux"
      &&
        nixosAt lb [
          "environment"
          "variables"
          "PLATFORM"
        ] == [ "linux" ];
    den-user-packages-per-system = lib.all (n: out.packages.x86_64-linux ? ${n}) [
      "sw-lb-alice"
      "sw-stage-bob"
      "sw-web-1-alice"
    ];
    den-opt-in-projection =
      hmAt "${stage}/user:alice" [
        "home"
        "sessionVariables"
        "HMVALS"
      ] == [ "user" ]
      &&
        hmAt "${stage}/user:alice" [
          "home"
          "sessionVariables"
          "HOST_ENV"
        ] == [ "staging" ]
      &&
        hmAt "${stage}/user:bob" [
          "home"
          "sessionVariables"
          "HMVALS"
        ] == [ ];
    den-pipeline-stage =
      nixosAt lb [
        "networking"
        "firewall"
        "allowedTCPPorts"
      ] == [ [ 80 ] ]
      && lib.length (red "fw" lb) == 2;
    den-one-class-two-systems =
      gave "sink both" "os" stage && gave "sink both" "homeManager" "${stage}/user:bob";
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
      lib.hasInfix "bob@stage" p && !(lib.hasInfix "alice@lb," p) && !(lib.hasSuffix "alice@lb" p);
    den-producer-own-config =
      hmAt "${stage}/user:alice" [
        "home"
        "sessionVariables"
        "DEV"
      ] == [ "h:stage" ];
    # ── den-hoag (Den + Gen) capabilities ──
    hoag-settings-authority =
      (red "aspect-settings" web1).nginx == {
        gzip = true;
        workers = 8;
      }
      && (red "aspect-settings" web2).nginx.workers == 4
      &&
        (red "aspect-settings" stage).nginx == {
          gzip = false;
          workers = 1;
        };
    hoag-settings-conflict = hasMsg (with' (
      { sven, ... }:
      {
        sven.aspects.t2 = {
          at = sven.host.web-1;
          aspect-settings = {
            rank = 2;
            set.nginx.workers = 9;
          };
        };
      }
    )) "aspect-settings: two layers of rank 2 disagree";
    hoag-ci-strategies =
      (red "tuning" lb).value == {
        ports = [
          22
          80
          443
        ];
        color = "blue";
        accent = "blue";
      }
      && (red "tuning" stage).value.ports == [ 22 ]
      &&
        map (p: p.rank) (red "tuning" lb).provenance.ports == [
          0
          1
          2
        ];
    hoag-ci-claim-dedup =
      red "token-claims" "fleet:main" == {
        apitoken.sharers = [
          "web-1"
          "web-2"
        ];
        metrics.sharers = [ "web-1" ];
      };
    hoag-ci-lockdown =
      nixosAt lb [
        "environment"
        "etc"
        "db/lockdown"
        "text"
      ] == [ "web-2" ]
      &&
        nixosAt stage [
          "environment"
          "etc"
          "db/lockdown"
          "text"
        ] == [ "" ];
    hoag-ci-route-split =
      red "secret-claims" "fleet:main" == {
        api.by = "web-1";
      }
      && red "connect-claims" "fleet:main" == { api.by = "web-1"; };
    hoag-ci-demand-cascade =
      lib.sort (a: b: a < b) (
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
      ) == [
        "fleet:main/database:audit"
        "fleet:main/database:audit/connect:audit-url"
        "fleet:main/database:audit/secret:audit-pw"
        "fleet:main/database:orders"
        "fleet:main/database:orders/connect:orders-url"
        "fleet:main/database:orders/secret:orders-pw"
        "fleet:main/database:users"
        "fleet:main/database:users/connect:users-url"
        "fleet:main/database:users/secret:users-pw"
      ]
      &&
        (scope "fleet:main/database:orders").by == [
          "web-1"
          "web-2"
        ];
    hoag-ci-visible =
      out.visibleMotd == {
        a = "w1";
        b = "w2";
        w = "w1";
      };
    hoag-ci-suppress-chain =
      map (a: r.active.${a}.${lb}) [
        "sup-a"
        "sup-b"
        "sup-c"
        "sup-d"
      ] == [
        true
        false
        true
        false
      ];
    hoag-ci-class-share-per-class = out.classShare ? nixos && !(out.classShare ? homeManager);
    clan-members =
      lib.sort (a: b: a < b) (
        map (s: s.name) (lib.filter (s: s.kind == "member" && s.parent.id == lb) r.scopes)
      ) == [
        "backup.client"
        "backup.server"
        "fleet-sshd-for-backup.server"
        "sshd.server"
        "svc-a.default"
        "svc-b.default"
      ]
      &&
        lib.sort (a: b: a < b) (
          map (s: s.name) (lib.filter (s: s.kind == "member" && s.parent.id == studio) r.scopes)
        ) == [
          "banner.default"
          "sshd.server"
        ];
    clan-settings-layers =
      nixosAt stage [
        "environment"
        "etc"
        "wifi/networks"
        "text"
      ] == [ "home office" ]
      &&
        nixosAt lb [
          "services"
          "borgbackup"
          "jobs"
          "backup"
          "startAt"
        ] == [ "02:00" ];
    clan-interface-default =
      osAt studio [
        "environment"
        "etc"
        "banner"
        "text"
      ] == [ "managed by sven" ];
    clan-multi-instance =
      lib.sort (a: b: a < b) (
        lib.concatMap lib.attrNames (
          nixosAt lb [
            "users"
            "users"
          ]
        )
      ) == [
        "svc-a"
        "svc-b"
      ];
    clan-per-machine =
      lib.length (
        osAt lb [
          "services"
          "openssh"
          "enable"
        ]
      ) == 1
      && (
        let
          es = lib.filter (e: e.origin == "aspect clan-sshd") r.graph.edges;
        in
        es != [ ] && lib.all (e: e.from == e.to) es
      )
      &&
        lib.length (lib.filter (s: s.kind == "member" && s.parent.id == lb && s.service == "sshd") r.scopes)
        == 2;
    clan-exports =
      nixosAt web1 [
        "services"
        "borgbackup"
        "jobs"
        "backup"
        "repo"
      ] == [ "borg@10.0.1.1:/srv/web-1" ]
      &&
        map (e: "${e.service}:${e.instance}:${e.role}:${e.machine}") (red "exports" "fleet:main") == [
          "borg:backup:server:lb"
          "site:docs:default:web-1"
        ];
    clan-exports-owned =
      map (e: e.service) (red "exports" "fleet:main" ++ [ ]) == [
        "borg"
        "site"
      ]
      &&
        lib.sort (a: b: a < b) (
          map (e: e.service) (
            (with' (
              { sven, ... }:
              {
                sven.aspects.forge = {
                  at = sven.lib.all [
                    sven.kinds.member
                    (s: s.service == "sshd")
                  ];
                  exports = {
                    service = "borg";
                  };
                };
              }
            )).reduced.exports."fleet:main"
          )
        ) == [
          "borg"
          "site"
          "sshd"
        ];
    clan-exports-per-instance =
      let
        x = with' (
          { ... }:
          {
            sven.instance.offsite = {
              module = "borg";
              roles = {
                client.machines.web-1 = { };
                server.machines.web-2 = { };
              };
            };
          }
        );
        job =
          n: map (v: v.services.borgbackup.jobs.${n}.repo or null) (list (x.reduced.nixos.${web1} or null));
      in
      lib.elem "borg@10.0.1.11:/srv/web-1" (job "offsite")
      && lib.elem "borg@10.0.1.1:/srv/web-1" (job "backup");
    clan-role-union =
      let
        x = with' (
          { ... }:
          {
            sven.instance.mix = {
              module = "banner";
              roles.default = {
                tags = [ "darwin" ];
                machines.web-1 = { };
              };
            };
          }
        );
      in
      lib.sort (a: b: a < b) (
        map (s: s.parent.name) (lib.filter (s: s.kind == "member" && s.instance or null == "mix") x.scopes)
      ) == [
        "studio"
        "web-1"
      ];
    clan-export-allowlist = hasMsg (with' (
      { sven, ... }:
      {
        sven.aspects.leak = {
          at = sven.lib.all [
            sven.kinds.member
            (s: s.service == "borg" && s.role == "server")
          ];
          exports =
            { scope, ... }:
            {
              token = "x";
            };
        };
      }
    )) ".*borg:backup:server:lb: service borg does not export token.*";
    clan-export-override =
      let
        x = with' (
          { sven, ... }:
          {
            sven.aspects.owner-pin = {
              at = sven.kinds.fleet;
              exports = {
                service = "borg";
                instance = "backup";
                role = "server";
                machine = "lb";
                value.repo = "borg@vault";
              };
            };
          }
        );
      in
      lib.elem "borg@vault:/srv/web-1" (
        map (v: v.services.borgbackup.jobs.backup.repo or null) (list (x.reduced.nixos.${web1} or null))
      );
    clan-vars-plan =
      let
        p = out.varsPlan.web-1;
      in
      lib.elem {
        generator = "borg-backup";
        file = "passphrase";
        path = "/run/secrets-for-users/vars/borg-backup/passphrase";
        neededForUsers = true;
      } p.files
      && lib.elem {
        generator = "openssh";
        file = "ssh.id_ed25519";
        path = "/run/secrets/vars/openssh/ssh.id_ed25519";
        neededForUsers = false;
      } p.files
      &&
        lib.findFirst (n: n == "openssh" || n == "borg-backup") null (map (g: g.name) p.order) == "openssh"
      && lib.any (f: f.generator == "wifi.home") out.varsPlan.stage.files
      && !(lib.any (f: f.generator == "wifi.home") out.varsPlan.lb.files);
    clan-export-generators =
      (red "generators" "fleet:main")."from-exports@web-1".files == {
        "borg.known_hosts".secret = false;
      }
      && !((red "generators" "fleet:main") ? "from-exports@web-2");
    clan-secret-read = hasMsg (with' (
      { sven, ... }:
      {
        sven.aspects.peek = {
          at = sven.host.web-1;
          public-reads = {
            machine = "web-1";
            generator = "openssh";
            file = "ssh.id_ed25519";
          };
        };
      }
    )) ".*web-1 reads openssh/ssh.id_ed25519, a secret file.*";
    clan-store-consistency = hasMsg (with' (
      { ... }:
      {
        sven.host.web-2.secretStore = "age";
      }
    )) ".*web-2 uses secret store age, the fleet uses sops.*";
    clan-darwin-restart = hasMsg (with' (
      { ... }:
      {
        sven.instance.backup-mac = {
          module = "borg";
          roles = {
            client.machines.studio = { };
            server.machines.lb = { };
          };
        };
      }
    )) ".*borg-backup-mac: restartUnits is NixOS only.*";
    clan-dir-hosts =
      lib.elem "from-dir" (scope web2).labels && !(lib.any (s: s.name == "notes.txt") r.scopes);
    clan-unknown-tag-warns =
      lib.flatten (red "warnings" "fleet:main") == [ ]
      && (
        let
          x = with' (
            { ... }:
            {
              sven.instance.ghost = {
                module = "banner";
                roles.default.tags = [ "nobody" ];
              };
            }
          );
        in
        lib.flatten (x.reduced.warnings."fleet:main")
        == [ "clan: instance ghost role default: tag nobody matches no machine" ]
        && !lib.any (e: lib.hasInfix "nobody" e.error) x.errors
      );
    clan-cross-service-exports =
      out.cnames == [
        {
          name = "docs.example.org";
          target = "web-1";
        }
      ];
    clan-vars-deploy-false =
      !lib.any (f: f.file == "ca-key") out.varsPlan.stage.files
      && lib.any (f: f.file == "password") out.varsPlan.stage.files;
    clan-recipients =
      out.varsPlan.lb.recipients == [
        "age1lb"
        "age1admin"
      ]
      && out.varsPlan.web-1.recipients == [ "age1admin" ];
    graphs-impact =
      noApps out.impact == {
        lb = [
          "stage"
          "web-1"
          "web-2"
        ];
        stage = [ ];
        web-1 = [ "stage" ];
        web-2 = [ ];
      }
      && hasMsg (with' (
        { sven, ... }:
        {
          sven.host.lb.dependsOn = [ sven.host.stage ];
        }
      )) "deploy: hosts depend on each other in a cycle: lb -> stage -> web-1";
    datalog-serving =
      let
        etc =
          r: f:
          lib.filter (v: v != null) (
            map (m: m.environment.etc.${f}.text or null) (list (r.reduced.nixos.${lb} or null))
          );
      in
      etc r "lb/serving" == [ "stage web-1 web-2" ]
      && etc r "db/primary" == [ "lb" ]
      &&
        etc (with' (
          { ... }:
          {
            sven.host.web-2.maintenance = true;
          }
        )) "lb/serving" == [ "stage web-1" ]
      &&
        etc (with' (
          { ... }:
          {
            sven.host.web-1.maintenance = true;
          }
        )) "lb/serving" == [ "web-2" ] # stage depends on web-1: drained too
      && lib.hasInfix "web:web-1" (lib.head (etc r "lb/why-web-1"));
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
      p == {
        grafana = 8081;
        loki = 8082;
        prometheus = 8080;
      }
      && p.prometheus < p.grafana
      && lib.length (lib.unique (lib.attrValues p)) == 3
      && hasMsg (with' (
        { ... }:
        {
          sven.host.web-2 = {
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
      )) ".*no allocation for web-2: 2 apps, ports 9000 9000.*";
    krn-memory =
      let
        mem =
          x:
          lib.filter (v: v != null) (
            map (m: m.environment.etc."guests/memory".text or null) (list (x.reduced.nixos.${stage} or null))
          );
        guest =
          n: r:
          { sven, ... }:
          {
            sven.guest.${n} = {
              environment = sven.environment.staging;
              channel = sven.channel.stable;
              system = sven.system.x86_64-linux;
              addr = "10.0.2.3${toString (lib.length r)}";
              on = sven.host.stage;
              ramRange = r;
            };
          };
      in
      mem r == [ (builtins.toJSON { ci = 8; }) ]
      &&
        mem (
          with' (
            guest "build" [
              4
              8
            ]
          )
        ) == [
          (builtins.toJSON {
            build = 8;
            ci = 2;
          })
        ]
      && hasMsg (with' (
        guest "big" [
          9
          12
        ]
      )) ".*the guests of stage do not fit in 16 GiB with 6 reserved.*"
      && (
        let
          x = with' (
            { ... }:
            {
              sven.host.stage.ramFuel = 3;
            }
          );
        in
        hasMsg x ".*the search for stage ran out of fuel.*" && mem x == [ ]
      );
    krn-placement =
      noApps out.dbPlacement == {
        lb = [ "lb" ];
        stage = [ "stage" ];
        web-1 = [ "lb" ];
        web-2 = [ "lb" ];
      }
      &&
        lib.sort (a: b: a < b) out.takes8081 == [
          "grafana"
          "loki"
          "prometheus"
        ];
    agent-check =
      r.check.ok
      &&
        r.check.invariants == [
          "attic"
          "base"
          "db-same-env"
          "ssh"
          "trust-order"
          "unique-addr"
        ]
      && r.check.violations == [ ];
    agent-stage =
      let
        s = sven.stage {
          base = fleet [ ];
          change = {
            sven.aspects.attic.at = [
              {
                kind = "mac";
                name = "studio";
              }
            ];
          };
        };
      in
      !s.ok
      && s.violations == [ "bad:attic-on-mac:${studio}" ]
      && s.diff.active.added == [ "attic@${studio}" ]
      && b.isString s.render;
    agent-grant =
      let
        g = sven.grant { scopes = [ S ]; };
        st =
          to:
          sven.stage {
            base = fleet [ ];
            change = {
              sven.aspects.attic.at = [ to ];
            };
            grant = g;
            invariants = false;
          };
      in
      (st {
        kind = "host";
        name = "stage";
      }).refused == [ ]
      &&
        lib.unique (
          map (e: e.code)
            (st {
              kind = "host";
              name = "web-1";
            }).refused
        ) == [ "outside-grant" ];
    agent-explain =
      let
        e = r.explain "attic" lb 2;
      in
      e.active && lib.any (f: lib.hasSuffix "modules/sini/secrets.nix" f) e.files && e.gives != [ ];
    agent-context =
      let
        c = r.context lb { maxEdges = 5; };
      in
      c.received.truncated.shown == 5 && c.received.truncated.of > 5 && b.fromJSON (b.toJSON c) == c;
    agent-schema =
      r.schema.kinds.host.sinks.deploy.reduce == "one"
      && r.schema.kinds.environment.sinks.k3s-nodes.reduce == "entries"
      && b.elem "sshd" (lib.attrNames r.schema.aspects) == false
      && r.schema.aspects.clan-sshd.activeAt > 0
      && b.fromJSON (b.toJSON r.agent) == r.agent;
    agent-whynot =
      let
        w = out.serving.whyNot;
      in
      w.lb != [ ]
      && lib.any (x: x.missing == [ "web:lb" ]) w.lb
      && w.web-1 == [ ]
      && out.serving.primary == "unknown"
      && lib.hasInfix "serves:web-1" (
        lib.head (
          lib.filter (v: v != null) (
            map (m: m.environment.etc."lb/proof-web-1".text or null) (list (red "nixos" lb))
          )
        )
      );
    agent-rdf =
      let
        p = sven.rdf.share r;
        q = sven.rdf.share (
          sven.eval (fleet [
            (
              { sven, ... }:
              {
                sven.aspects.extra = {
                  at = sven.host.lb;
                  persist = "/var/lib/extra";
                };
              }
            )
          ])
        );
      in
      lib.hasPrefix "<" p.ntriples
      && p.count > 1000
      && p.sha256 != q.sha256
      && out.rdfPack.count > 0
      && b.isString out.rdfPack.sha256;
    agent-queries =
      r.queries.hostsIn == {
        required = [ "env" ];
        optional = [ ];
      }
      &&
        r.ask "hostsIn" { env = "prod"; } == [
          "lb"
          "lb-minimal"
          "web-1"
          "web-2"
        ]
      && lib.elem "attic" (r.ask "aspectsOn" { host = "lb"; })
      && (r.ask "hostsIn" { }).code == "missing-param"
      && r.ask "errorsBy" { } == [ ];
    agent-mcp-app =
      out.apps.x86_64-linux.sven-mcp.type == "app"
      && lib.hasSuffix "/bin/sven-mcp" out.apps.x86_64-linux.sven-mcp.program;
    agent-labels =
      r.labels.rdf-pack.trust == 1
      && r.labels.attic.trust == 3
      && lib.all (
        x:
        lib.elem x.aspect [
          "rdf-pack"
          "serving-explain"
          "retire-notice"
          "mcp-app"
        ]
      ) (r.floor 3)
      && r.floor 1 == [ ];
    agent-valid-time = r.active.retire-notice.${web2} && !r.active.retire-notice.${web1};
    agent-impact =
      let
        i = r.impact lb { hops = 1; };
      in
      lib.any (x: x.scope == P && x.depth == 1) i.reached
      && (r.impact lb { sinks = [ "nixos" ]; }).reached == [ ];
    agent-without =
      let
        files = lib.filter (f: lib.hasSuffix ".nix" (toString f) && !lib.hasPrefix "_" (baseNameOf f)) (
          lib.filesystem.listFilesRecursive ./modules
        );
        w = sven.without {
          inherit files;
          path = [
            "aspects"
            "attic"
          ];
          args = { inherit inputs lib; };
        };
      in
      map baseNameOf w.dropped == [ "secrets.nix" ] && !(w.r.active ? attic);
    krn-fuel =
      let
        K = sven.krn;
        fives =
          x:
          K.disj [
            (K.eq x 5)
            (fives x)
          ];
        s = K.runAllFuel 40 (q: fives q);
      in
      !s.complete && s.answers != [ ] && lib.all (x: x == 5) s.answers;
    agent-shacl =
      let
        t = sven.rdf.shacl r;
      in
      lib.hasInfix "sh:targetClass <https://sven.dev/fleet/kind/host>" t
      && lib.hasInfix "<https://sven.dev/fleet/field/environment> ; sh:maxCount 1 ; sh:class <https://sven.dev/fleet/kind/environment>" t
      # a line of the pack, not a regex over 700 KB: `.*` regexes recurse per character and overflow the stack (nix 2.35)
      && lib.elem "<https://sven.dev/fleet/instance/environment/lab> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <https://sven.dev/fleet/kind/environment> ." (
        lib.splitString "\n" (sven.rdf.ntriples r)
      );
    # an agent's change between machines is refused BEFORE deploy, with the reason
    safety-db-cross-env =
      let
        s = sven.stage {
          base = fleet [ ];
          change =
            { sven, ... }:
            {
              sven.host.app-4.dbOn = sven.host.stage;
            };
        };
      in
      !s.ok
      && s.violations == [ "bad:db-cross-env:fleet:main/environment:lab/host:app-4" ]
      &&
        r.check.whyNot "bad:db-cross-env:fleet:main/environment:lab/host:app-4" == [
          {
            rule = null;
            reason = "no rule has this head";
          }
        ]; # not even a candidate today
    safety-addr-clash =
      let
        s = sven.stage {
          base = fleet [ ];
          change =
            { sven, ... }:
            {
              sven.host.rogue = {
                environment = sven.environment.lab;
                channel = sven.channel.stable;
                system = sven.system.x86_64-linux;
                addr = "10.0.1.1";
              };
            };
        };
      in
      !s.ok && s.violations == [ "bad:addr-clash:10.0.1.1" ];
    safety-trust-order =
      let
        s = sven.stage {
          base = fleet [ ];
          change =
            { sven, ... }:
            {
              sven.host.app-4.dependsOn = [ sven.host.stage ];
            };
        };
      in
      !s.ok
      && s.violations == [ "bad:trust-down:fleet:main/environment:lab/host:app-4:stage" ]
      &&
        (sven.stage {
          base = fleet [ ];
          change =
            { sven, ... }:
            {
              sven.host.app-4.dependsOn = [ sven.host.lb ];
            };
        }).violations == [ ];
    synth-free-port =
      let
        a = r.ask "freePort" { host = "lb"; };
      in
      a.port == 8083
      &&
        lib.sort (x: y: x < y) a.used == [
          8080
          8081
          8082
        ]
      && (r.ask "freePort" { host = "web-1"; }).port == 8080;
    synth-place-db =
      r.ask "placeDb" { host = "web-1"; } == [ "lb" ]
      && r.ask "placeDb" { host = "stage"; } == [ "stage" ];
    synth-safe-hosts =
      r.ask "safeHostsFor" {
        aspect = "attic";
        env = "staging";
      } == {
        safe = [ "stage" ];
        refused.studio = [ "bad:attic-on-mac:fleet:main/environment:staging/mac:studio" ];
      };
    clan-install-order =
      let
        w = r.ask "installOrder" { instance = "backup"; };
      in
      lib.head w == [ "lb" ]
      && lib.length w == 2
      && lib.elem "web-1" (lib.elemAt w 1)
      && !(lib.elem "lb" (lib.elemAt w 1));
    clan-extra-modules = lib.elem { imports = [ { environment.etc."extra".text = "svc-a"; } ]; } (
      list (red "os" lb)
    );
    clan-contract =
      let
        e = with' (
          { sven, ... }:
          {
            sven.instance = {
              bad-role.roles.nope.machines.lb = { };
              empty = {
                module = "sshd";
                roles = { };
              };
              backup2 = {
                module = "borg";
                roles.server.machines = {
                  lb = { };
                  web-1 = { };
                };
              };
              banner2 = {
                module = "banner";
                roles.default.machines.lb = { };
              };
              nouser = {
                module = "users";
                roles.default.machines.web-1 = { };
              };
              badtype = {
                module = "users";
                roles.default = {
                  machines.web-1 = { };
                  settings.user = 42;
                };
              };
            };
          }
        );
      in
      lib.all (hasMsg e) [
        ".*instance bad-role uses unknown service bad-role.*"
        ".*instance empty has no roles.*"
        ".*backup2 role server: 2 machines, at most 1.*"
        ".*nouser.default: setting user is not a string.*"
        ".*badtype.default: setting user is not a string.*"
      ];
    clan-vars =
      noApps (lib.sort (a: b: a < b) (lib.attrNames (red "generators" "fleet:main"))) == [
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
      ]
      && hasMsg (with' (
        { sven, ... }:
        {
          sven.aspects.dep-bad = {
            at = sven.host.web-1;
            generators =
              { scope, ... }:
              {
                name = "x";
                dependencies = [ "missing" ];
              };
          };
        }
      )) ".*x@web-1 depends on missing, which web-1 has not.*";
    clan-public-value =
      osAt lb [
        "environment"
        "etc"
        "ssh/host-key.pub"
        "text"
      ] == [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFleetTestKeyNotReal lb" ]
      &&
        osAt web1 [
          "environment"
          "etc"
          "ssh/host-key.pub"
          "text"
        ] == [ "absent" ];
    clan-autoinclude =
      lib.any (m: lib.isAttrs m && lib.elem ./machines/web-2/configuration.nix (m.imports or [ ])) (
        list (red "nixos" web2)
      )
      && !r.active.autoinclude.${web1};
    hoag-claims-reverse-read =
      first (
        nixosAt lb [
          "services"
          "postgresql"
          "ensureDatabases"
        ]
      ) == [
        "app_web_1"
        "app_web_2"
      ]
      &&
        first (
          nixosAt stage [
            "services"
            "postgresql"
            "ensureDatabases"
          ]
        ) == [ "app_stage" ]
      &&
        first (
          nixosAt web1 [
            "services"
            "postgresql"
            "ensureDatabases"
          ]
        ) == null
      &&
        first (
          nixosAt web1 [
            "environment"
            "etc"
            "app/database-url"
            "text"
          ]
        ) == "postgres://10.0.1.1/app_web_1";
    hoag-collectors =
      lib.attrNames out.colmenaHives.prod == [
        "lb"
        "meta"
        "web-1"
        "web-2"
      ]
      &&
        lib.attrNames out.colmenaHives.staging == [
          "meta"
          "stage"
        ]
      && out.colmenaHives.staging.meta.allowApplyAll;
    hoag-query-layers =
      map noApps out.deployWaves == [
        [ "lb" ]
        [
          "web-1"
          "web-2"
        ]
        [ "stage" ]
      ]
      &&
        out.dependents.lb == [
          "web-1"
          "web-2"
        ]
      && out.dependents.stage == [ ];
  };

  e2e = rec {
    lbCfg = out.nixosConfigurations.lb.config;
    checks = {
      lb-toplevel = lib.hasSuffix ".drv" lbCfg.system.build.toplevel.drvPath;
      # every CI target evaluates to a derivation (assertions included): the darwin system too
      studio-toplevel =
        let
          x = builtins.tryEval out.darwinConfigurations.studio.config.system.build.toplevel.drvPath;
        in
        x.success && lib.hasSuffix ".drv" x.value; # a failed assertion is a throw: named red
      # trimmed base module lists: the same toplevel as the full list; a list without nginx fails for a host that sets it
      modlist-same-drv =
        let
          d = c: c.config.system.build.toplevel.drvPath;
        in
        lib.attrNames out.nixosConfigurationsFull == [
          "app-2"
          "web-1"
        ]
        && lib.all (n: d out.nixosConfigurations.${n} == d out.nixosConfigurationsFull.${n}) [
          "app-2"
          "web-1"
        ];
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
        !(builtins.tryEval (sys true).config.system.build.toplevel.drvPath).success
        && (builtins.tryEval (sys false).config.system.build.toplevel.drvPath).success; # the same list with nginx builds
      shared-pkgs-same-drv =
        let
          d = c: c.config.system.build.toplevel.drvPath;
        in
        # every follower: its toplevel on the shared pkgs equals its toplevel on its own pkgs
        lib.all (n: out.sharedPkgs.${n}.follower) (lib.attrNames out.nixosConfigurationsOwnPkgs)
        &&
          lib.attrNames out.nixosConfigurationsOwnPkgs == [
            "app-2"
            "app-3"
            "lb"
            "lb-minimal"
            "web-1"
            "web-2"
          ] # lb-minimal: lb's variant inherits sharedPkgs && out.sharedPkgs.lb.leader == "app-1"
        && lib.all (n: d out.nixosConfigurations.${n} == d out.nixosConfigurationsOwnPkgs.${n}) (
          lib.attrNames out.nixosConfigurationsOwnPkgs
        )
        && !(out.sharedPkgs ? app-4)
        && !(out.sharedPkgs ? stage);
      clan-built =
        lbCfg.services.borgbackup.jobs.backup.repo == "borg@10.0.1.1:/srv/lb"
        && lbCfg.users.users ? svc-a
        && lbCfg.users.users ? svc-b
        && lbCfg.services.openssh.enable
        && lbCfg.environment.etc.extra.text == "svc-a"
        && out.nixosConfigurations.web-2.config.environment.etc.autoinclude.text == "web-2"
        && out.nixosConfigurations.stage.config.environment.etc."wifi/networks".text == "home office"
        && out.darwinConfigurations.studio.config.environment.etc.banner.text == "managed by sven";
      lb-haproxy-order = lib.hasInfix "10.0.1.10:80 check\n  server 10.0.1.11" lbCfg.services.haproxy.config;
      lb-motd = lbCfg.environment.etc.motd.text == "managed by sven" && lbCfg.networking.hostName == "lb";
      lb-overlay = lib.length lbCfg.nixpkgs.overlays == 1;
      lb-flatten-class-lib =
        lbCfg.users.users.alice.description == "Alice" && lbCfg.users.users.alice.isNormalUser;
      lb-hm-alice =
        lbCfg.home-manager.users.alice.programs.git.enable
        && lbCfg.home-manager.users.alice.services.ssh-agent.enable;
      lb-age-manifest =
        out.ageManifest.lb == [ "attic-env" ] && lbCfg.age.secrets.attic-env.path == "/run/agenix/lb-attic";
      lb-specialisation = lbCfg.specialisation ? debug;
      lb-no-gui-passes = out.checks.x86_64-linux.lb-no-gui.drvAttrs.buildCommand == "touch $out";
      lb-no-gui-firefox-fails =
        lib.hasInfix "exit 1"
          (with' (
            {
              pkgs ? null,
              ...
            }:
            {
              sven.aspects.firefox = {
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
          )).flake.checks.x86_64-linux.lb-no-gui.drvAttrs.buildCommand;
      studio-darwin =
        let
          c = out.darwinConfigurations.studio.config;
        in
        c.system.defaults.dock.autohide
        && c.networking.hostName == "studio"
        && c.home-manager.users.bob.programs.aerospace.enable;
      home-edge =
        let
          c = out.homeConfigurations.alice-laptop.config;
        in
        c.programs.git.enable && !c.services.ssh-agent.enable && c.home.username == "alice";
      den-739-standalone-home =
        out.homeConfigurations."alice@stage".config.home.sessionVariables.MONITORRES == "2560x1440";
      infra-lb-passes = out.checks.x86_64-linux.infra-lb.drvAttrs.buildCommand == "touch $out";
      infra-lb-drift-fails =
        lib.hasInfix "networking.hostName"
          (with' {
            sven.aspects.drift = {
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
          }).flake.checks.x86_64-linux.infra-lb.drvAttrs.buildCommand;
      den-enrichment-built =
        lbCfg.environment.variables.PLATFORM == "linux"
        && lib.hasInfix "bob@stage" lbCfg.environment.etc.peers.text
        && lib.elem 80 lbCfg.networking.firewall.allowedTCPPorts
        && !(lib.elem 53 lbCfg.networking.firewall.allowedTCPPorts); # 2200 is ssh-port
      den-producer-own-config-built =
        out.homeConfigurations."alice@stage".config.home.sessionVariables.HOST_DESKTOP == "yes";
      hoag-class-share-gate =
        out.classShare.nixos.members.lb.gate
        && out.classShare.nixos.coreSize > 0
        && out.classShare.nixos.members.lb.deltaSize < out.classShare.nixos.members.lb.fullSize;
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
        bad.config.system.build.toplevel.drvPath != lbCfg.system.build.toplevel.drvPath;
      den-713-home-reads-host-config =
        out.homeConfigurations."alice@stage".config.home.sessionVariables.HOST_DESKTOP == "yes";
      # osConfig sink: a nested user and a standalone home under a host read the host's config; pkgs is home-manager's
      os-config-nested =
        lbCfg.home-manager.users.alice.home.sessionVariables.EDITOR_HOST == "lb"
        && lib.any (p: lib.getName p == "nano") lbCfg.home-manager.users.alice.home.packages;
      os-config-standalone =
        let
          c = out.homeConfigurations."alice@stage".config;
        in
        c.home.sessionVariables.EDITOR_HOST == "stage"
        && lib.any (p: lib.getName p == "nano") c.home.packages;
      hoag-claims-built = lib.elem "app_web_1" out.nixosConfigurations.lb.config.services.postgresql.ensureDatabases;
      den-chained-forward-built =
        out.nixosConfigurations.lb.config.home-manager.users.alice.programs.git.extraConfig.init.defaultBranch
        == "main"; # lb: stable channel, HM 25.05
      lb-minimal-built =
        lib.hasSuffix ".drv" out.nixosConfigurations.lb-minimal.config.system.build.toplevel.drvPath
        && !out.nixosConfigurations.lb-minimal.config.services.haproxy.enable;
      export-module =
        (inputs.nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            out.nixosModules.base
            {
              boot.loader.grub.device = "nodev";
              fileSystems."/".device = "x";
              system.stateVersion = "25.05";
            }
          ];
        }).config.environment.etc.motd.text == "managed by sven";
    };
    failed = lib.filter (n: !checks.${n}) (lib.attrNames checks);
  };
in
{
  inherit
    checks
    e2e
    r
    with'
    ;
  failed = lib.filter (n: !checks.${n}) (lib.attrNames checks);
}
