# den-hoag's acceptance fleet (`ci/tests/_fixtures/fleet.nix` `acceptance`) in yen, with the assertions of its
# `ci/tests/end-to-end.nix`. Copies: vic/ref/den-hoag/acceptance-fleet.nix, vic/ref/den-hoag/tests/end-to-end.nix.
# Run: nix eval --offline --impure --file hoag-acceptance.nix failed        (expect [ ])
let
  inputs = (builtins.getFlake "path:${toString ../..}?dir=templates/fleet").inputs;
  inherit (inputs.nixpkgs) lib;
  yen = inputs.yen.lib;

  # ── the fleet ──
  schema =
    { yen, ... }:
    {
      # den-hoag has two roots (env, cluster). In yen one root holds both, so data has a common ancestor.
      yen.kinds.fleet = {
        spawns = {
          env = _: yen.env;
          cluster = _: yen.cluster;
        };
        sinks = {
          out.reduce = yen.lib.reduce.merge;
          ssh-peers.reduce = yen.lib.reduce.entries;
          demands.reduce = yen.lib.reduce.entries;
        };
      };
      yen.kinds.env.spawns.host = s: lib.filterAttrs (_: h: yen.lib.same h.env s) yen.host;
      yen.kinds.host = {
        fields.env = yen.kinds.env;
        spawns.user = s: lib.filterAttrs (_: u: lib.any (yen.lib.same s) u.on) yen.user; # membership tuples
        sinks = {
          nixos.out =
            { host, nixos, ... }:
            {
              nixosConfigurations.${host.name} = inputs.nixpkgs.lib.nixosSystem { modules = nixos; };
            };
          http-backends = { };
          probe = { };
        };
      };
      yen.kinds.user = {
        fields.on = yen.helpers.listOf yen.kinds.host;
        sinks.settings.reduce = layers;
      };
      yen.kinds.cluster = {
        fields.hosts = yen.helpers.listOf yen.kinds.host;
        spawns = { };
      }; # a link: refs, not containment
      yen.helpers.listOf = t: yen.lib.is (v: lib.isList v && lib.all t.check v);
      yen.fleet.main = { };
      yen.env.prod = { };
      yen.host = {
        igloo.env = yen.env.prod;
        web-1.env = yen.env.prod;
      };
      yen.user = {
        tux.on = [
          yen.host.igloo
          yen.host.web-1
        ];
        admin.on = [ yen.host.igloo ];
      };
      yen.cluster.k3s.hosts = [
        yen.host.igloo
        yen.host.web-1
      ];
      yen.flake = { out, ... }: out;
    };

  # settings layers with provenance: { rank; set; via ? null }, ordered by rank (authority), last wins
  layers =
    es:
    let
      sorted = lib.sort (a: b: a.value.rank < b.value.rank) es;
    in
    {
      value = {
        value = lib.foldl' (acc: e: acc // e.value.set) { } sorted;
        provenance = lib.genAttrs (lib.unique (lib.concatMap (e: lib.attrNames e.value.set) sorted)) (
          k:
          map (e: {
            value = e.value.set.${k};
            via = e.value.via or null;
          }) (lib.filter (e: e.value.set ? ${k}) sorted)
        );
      };
      errors = [ ];
    };

  aspects =
    { yen, ... }:
    {
      # `system`: each host's nixos binds its own name
      yen.aspects.system = {
        at = [
          yen.host.igloo
          yen.host.web-1
        ];
        nixos =
          { host, ... }:
          {
            networking.hostName = host.name;
            nixpkgs.hostPlatform = "x86_64-linux";
            boot.loader.grub.device = "nodev";
            fileSystems."/".device = "/dev/sda1";
            system.stateVersion = "25.05";
          };
      };
      # `app`: radiates to every user under prod (neededBy user), never to the hosts
      yen.aspects.app = {
        at = yen.lib.all [
          yen.kinds.user
          (yen.lib.within yen.env.prod)
        ];
        settings = {
          rank = 0;
          set.colorScheme = "base";
        };
      };
      # `gruvbox-theme`: the projector at env:prod, onto every aspect that declares `colorScheme`
      yen.aspects.gruvbox-theme = {
        at = yen.lib.all [
          yen.kinds.user
          (yen.lib.within yen.env.prod)
        ];
        settings = {
          rank = 1;
          via = "gruvbox-theme";
          set = lib.optionalAttrs (lib.any (
            n:
            (yen.aspects.${n}.settings.set or { }) ? colorScheme
            && (yen.aspects.${n}.settings.rank or null) == 0
          ) (lib.attrNames yen.aspects)) { colorScheme = "fleet-gruvbox"; };
        };
      };
      yen.aspects.igloo-override = {
        at = yen.lib.all [
          yen.kinds.user
          (yen.lib.within yen.host.igloo)
        ];
        settings = {
          rank = 2;
          set.colorScheme = "igloo-host";
        };
      };
      yen.aspects.setColor = {
        at = yen.kinds.user;
        settings = {
          rank = 3;
          set.colorScheme = "prod-policy";
        };
      }; # the configure policy: terminal slot
      # guard-activated neededBy: guardG holds where `system` holds; needT holds where guardG holds
      yen.aspects.guardG.at = yen.aspects.system;
      yen.aspects.needT.at = yen.aspects.guardG;
      # quirks
      yen.aspects.peerIgloo = {
        at = yen.host.igloo;
        ssh-peers = "igloo-ip";
      };
      yen.aspects.peerWeb = {
        at = yen.host.web-1;
        ssh-peers = "web1-ip";
      };
      yen.aspects.backendA = {
        at = yen.host.igloo;
        http-backends = "backend-a";
      };
      yen.aspects.backendB = {
        at = yen.host.igloo;
        http-backends = "backend-b";
      };
      yen.aspects.cluster-peers = {
        # the cluster gathers ssh-peers through its link (a reader filter)
        at = yen.kinds.cluster;
        out =
          { cluster, ssh-peers, ... }:
          {
            clusterPeers.${cluster.name} = map (e: e.value) (
              lib.filter (e: lib.any (yen.lib.same e.from) cluster.hosts) ssh-peers
            );
          };
      };
    };

  # the database demand cascade: database (depth 1) desugars into secret + connect (depth 0)
  demandKinds = {
    database = {
      below = [
        "secret"
        "connect"
      ];
      resolve = d: { resources."db/${d.subject}".engine = "postgres"; };
    };
    secret = {
      below = [ ];
      resolve = d: { resources."secret/${d.subject}".seed = "prod-seed"; };
    };
    connect = {
      below = [ ];
      resolve = d: { wiring.endpoint = "svc/${d.subject}"; };
    };
  };
  demands =
    { yen, ... }:
    {
      yen.aspects.provisionDb = {
        at = yen.cluster.k3s;
        demands = {
          kind = "database";
          subject = "igloo";
        };
      };
      yen.aspects.demand-cascade = {
        at = yen.fleet.main;
        out =
          { demands, ... }:
          let
            all = map (x: x.d) (
              builtins.genericClosure {
                startSet = map (e: {
                  key = "${e.value.kind}/${e.value.subject}";
                  d = e.value;
                }) demands;
                operator =
                  x:
                  map (k: {
                    key = "${k}/${x.d.subject}";
                    d = x.d // {
                      kind = k;
                    };
                  }) demandKinds.${x.d.kind}.below;
              }
            );
            res = map (d: d // { r = demandKinds.${d.kind}.resolve d; }) all;
          in
          {
            demands = lib.foldl' lib.recursiveUpdate { } (map (d: d.r.resources or { }) res); # providers
            wiring = lib.foldl' lib.recursiveUpdate { } (map (d: { ${d.subject} = d.r.wiring or { }; }) res); # consumers, by subject
          };
      };
      yen.aspects.demand-wiring = {
        # the consumer side lands in the subject's own config
        at = yen.kinds.host;
        nixos =
          { host, out, ... }:
          {
            environment.etc."wiring".text = builtins.toJSON (out.wiring.${host.name} or { });
          };
      };
    };

  # unrelated policy modules (den-hoag permutes them; order must not matter)
  link =
    { yen, ... }:
    {
      yen.aspects.link-note = {
        at = yen.cluster.k3s;
        out =
          { cluster, ... }:
          {
            clusterImports.${cluster.name} = map (h: "host:${h.name}") cluster.hosts;
          };
      };
    };
  modules = [
    schema
    aspects
    demands
    link
  ];
  mk =
    ms:
    yen.eval {
      imports = ms;
      _module.args = { inherit lib; };
    };
  r = mk modules;
  rp = mk (lib.reverseList modules);
  out = r.flake;
  hasAt = a: id: r.active.${a}.${id} or false;
  igloo = "fleet:main/env:prod/host:igloo";
  web1 = "fleet:main/env:prod/host:web-1";
  tuxIgloo = "${igloo}/user:tux";
  rs = r.reduced.settings.${tuxIgloo};

  deferred = mk (
    modules
    ++ [
      (
        { yen, ... }:
        {
          yen.aspects.deferredProbe = {
            at = yen.host.igloo;
            probe = { config, ... }: "host-is-${config.networking.hostName}"; # a value that reads the producer's config
            nixos =
              { probe, config, ... }:
              {
                networking.domain = (lib.head probe) { inherit config; };
              };
          };
        }
      )
    ]
  );
  saboteur = mk (
    modules
    ++ [
      (
        { yen, ... }:
        {
          yen.aspects.saboteur = {
            at = yen.host.web-1;
            http-backends = builtins.throw "web-1 sibling content boom";
          };
        }
      )
    ]
  );

  checks = {
    mkden-return-shape = r ? errors && r ? graph && out ? nixosConfigurations && r.errors == [ ];
    graph-trace-stable = builtins.toJSON r.graph == builtins.toJSON rp.graph;
    graph-trace-hashable =
      builtins.stringLength (builtins.hashString "sha256" (builtins.toJSON r.graph)) == 64;
    graph-trace-nonempty = r.graph.edges != [ ];
    fleet-cells =
      lib.sort (a: b: a < b) (
        map (s: "${s.name}@${s.parent.name}") (lib.filter (s: s.kind == "user") r.scopes)
      ) == [
        "admin@igloo"
        "tux@igloo"
        "tux@web-1"
      ];
    registration-scoped-delivery =
      [
        (hasAt "app" tuxIgloo)
        (hasAt "app" "${web1}/user:tux")
        (hasAt "app" "${igloo}/user:admin")
        (hasAt "app" igloo)
      ] == [
        true
        true
        true
        false
      ];
    guard-activated-neededby-fires =
      [
        (hasAt "guardG" igloo)
        (hasAt "needT" igloo)
        (hasAt "guardG" "fleet:main/env:prod")
      ] == [
        true
        true
        false
      ];
    cluster-link-resolves =
      out.clusterImports.k3s == [
        "host:igloo"
        "host:web-1"
      ];
    one-instantiate-per-host =
      lib.attrNames out.nixosConfigurations == [
        "igloo"
        "web-1"
      ];
    http-backends-order-stable = r.reduced.http-backends.${igloo} == rp.reduced.http-backends.${igloo};
    http-backends-order-canonical =
      r.reduced.http-backends.${igloo} == [
        "backend-a"
        "backend-b"
      ]; # yen's canonical order: aspect name (den-hoag: id_hash)
    settings-provenance-order =
      map (e: e.value) rs.provenance.colorScheme == [
        "base"
        "fleet-gruvbox"
        "igloo-host"
        "prod-policy"
      ];
    settings-policy-wins-terminal = rs.value.colorScheme == "prod-policy";
    settings-projection-via =
      map (e: e.via) rs.provenance.colorScheme == [
        null
        "gruvbox-theme"
        null
        null
      ];
    settings-web1-no-host-override =
      map (e: e.value) r.reduced.settings."${web1}/user:tux".provenance.colorScheme == [
        "base"
        "fleet-gruvbox"
        "prod-policy"
      ];
    ssh-peers-gathered-at-cluster =
      out.clusterPeers.k3s == [
        "igloo-ip"
        "web1-ip"
      ];
    demand-provider-materializes =
      out.demands."db/igloo" == {
        engine = "postgres";
      }
      && out.demands."secret/igloo".seed == "prod-seed";
    demand-consumer-materializes =
      out.wiring.igloo == { endpoint = "svc/igloo"; } && !(out.wiring ? web-1);
    demand-consumer-in-config =
      builtins.fromJSON out.nixosConfigurations.igloo.config.environment.etc.wiring.text == {
        endpoint = "svc/igloo";
      };
    nixos-hostname-igloo = out.nixosConfigurations.igloo.config.networking.hostName == "igloo";
    nixos-hostname-web1 = out.nixosConfigurations.web-1.config.networking.hostName == "web-1";
    deferred-channel-resolves-at-terminal =
      deferred.flake.nixosConfigurations.igloo.config.networking.domain == "host-is-igloo";
    laziness-sibling-does-not-block =
      (builtins.tryEval (builtins.deepSeq saboteur.reduced.http-backends.${igloo} true)).success;
    laziness-throwing-sibling-is-real =
      !(builtins.tryEval (builtins.deepSeq saboteur.reduced.http-backends.${web1} true)).success;
  };
in
{
  inherit checks;
  failed = lib.filter (n: !checks.${n}) (lib.attrNames checks);
}
