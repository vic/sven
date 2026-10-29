{
  title = "Fixpoints and dependencies";
  description = "Like NixOS `config`, a yen fleet is a fixpoint. Unlike `config`, every dependency is a routed edge you can query.";
  section = "concepts";
  order = 16;

  body =
    {
      docs,
      result,
      variant,
      ...
    }:
    [
      ''
        In NixOS, `config` is a fixpoint: every module reads the final `config`, and Nix laziness computes each value
        when something reads it. A yen fleet is a fixpoint too, in two layers:

        - **Declarations.** Every module gets `yen`, which is computed from the declarations of all modules,
          its own too. A module reads `yen.host.a.addr` from any file, as a NixOS module reads `config.x`.
        - **Results.** An element reads the reduced value of a sink through an arg. That value can hold elements
          that read other sinks. Sinks feed sources and sources feed sinks; laziness closes the loop.

        The order of the files and of the definitions never matters.

        ## Each NixOS pattern, in yen

        This fleet has two hosts. Each sink plays the part of one NixOS option:
      ''
      (docs.file "modules/fleet.nix")
      (docs.file "modules/aspects.nix")
      (docs.table
        [ "NixOS" "yen" "Here" ]
        [
          [
            "a list option many modules define"
            "a sink; each aspect gives an element"
            "`ports`"
          ]
          [
            "`mkIf config.services.web.enable`"
            "`at` refers to an aspect"
            "`tls.at = yen.aspects.web`"
          ]
          [
            "an option read from another option"
            "a sink arg"
            "`firewall = { ports, ... }: …`"
          ]
          [
            "a default computed from `config`"
            "`yen.lib.derive`"
            "`fqdn`"
          ]
          [
            "attrsets merged from many modules"
            "`reduce.merge`"
            "`settings`"
          ]
          [
            "`mkForce` and `mkDefault`"
            "a `reduce` that picks by priority"
            "`motd`"
          ]
          [
            "`nodes.<other>.config`"
            "give to a sink above both hosts, read it back"
            "`addrs`, `peers`"
          ]
        ]
      )
      (docs.value result.reduced)
      ''
        ## Dependencies are edges

        In NixOS, any module can read any option, so a dependency is a read hidden in a function. Nothing lists it,
        and "what changes if I change this?" has no answer before you evaluate.

        In yen, an element reads only what reaches its scope: its own scope, the nearest scope of a kind, and the
        sinks of its receivers. A value goes from one scope to another only as a routed element, and each routed
        element is an edge of `graph`, with the aspect that gave it. Here, `peers` on `a` reads what `b` gave to
        the fleet:
      ''
      (docs.value (builtins.filter (e: e.sink == "addrs") result.graph.edges))
      ''
        ## Where routing helps

        Because the edges are the dependencies, these questions are queries, not a search:

        - `result.impact id { }`: the scopes a scope's elements reach, by depth. See [History](/agents/history/).
        - `result.explain aspect id depth`: why an aspect is or is not active at a scope.
        - A grant limits the scopes and sinks a change may give to. It can check a change because every new
          dependency is a new edge. See [Stage a change](/agents/stage/).
        - Labels: an element carries the trust of the files that declare its aspect. See
          [Agent surface](/agents/agent-surface/).

        A read of any value of any scope would add dependencies that are not edges, and these answers would miss
        them. So yen has no such read. To read another host's value, give it to a sink of a scope above both hosts,
        as `addrs` does.

        ## What yen does not do

        NixOS resolves two values for one option with priorities: `mkForce` wins. yen never overrides data: two
        different values for one declared leaf are an error, and you keep one. For values that many files give,
        the sink's `reduce` decides, as `motd` does above.
      ''
      (docs.file "variants/override.nix")
      (docs.value (map (e: { inherit (e) code path; }) (variant "variants/override.nix").errors))
      (docs.note "Structure from results" ''
        In NixOS, `imports` cannot depend on `config`. In yen, `spawns` can depend on whether an aspect holds:
        `yen.lib.holds`. See [Predicates](/concepts/predicates/).
      '')
    ];

  checks =
    { result, variant, ... }:
    let
      at = sink: host: result.reduced.${sink}."fleet:main/host:${host}";
    in
    {
      aggregate = at "ports" "b" == [ 22 ];
      mkif =
        at "firewall" "a" == [
          22
          80
          443
        ];
      default-from-config =
        (builtins.head (builtins.filter (s: s.name == "a") result.scopes)).fqdn == "a.lan";
      deep-merge =
        at "settings" "b" == {
          log = {
            level = "info";
            file = "/var/log/b";
          };
        };
      priority = at "motd" "a" == "welcome" && at "motd" "b" == "maintenance";
      other-node = at "peers" "a" == { b = "10.0.0.2"; };
      edges =
        map (e: e.from) (builtins.filter (e: e.sink == "addrs") result.graph.edges) == [
          "fleet:main/host:a"
          "fleet:main/host:b"
        ];
      override = map (e: e.code) (variant "variants/override.nix").errors == [ "two-answers" ];
    };
}
