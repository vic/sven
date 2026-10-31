let
  site = "https://yen.oeiuwq.com";
  link = text: path: "[${text}](${site}${path})"; # absolute links
in
{
  title = "A fleet on one page";
  description = "Two environments, three hosts, a user, a service placed by a fact, and a rule across machines. One file.";
  section = "start";
  order = 4;

  body =
    {
      docs,
      inputs,
      dir,
      engine,
      result,
      ...
    }:
    let
      base = {
        imports = [ (inputs.import-tree (dir + "/modules")) ];
        inherit inputs;
        inherit (inputs.nixpkgs) lib;
        yen.sinks = {
          inputs = { };
          lib = { };
        };
      };
      staged = engine.stage {
        inherit base;
        change = dir + "/changes/api-in-lab.nix";
      };
    in
    [
      ''
        **yen is a query language for Nix configurations**: one file of Nix builtins, no dependencies, no module system,
        no fixpoint, and no `throw`. You describe a fleet as data and behavior. yen answers queries on it: the systems to build,
        the errors, the graph of who gives what to whom, and whether your rules hold across machines.

        yen is domain independent. Its engine does not know what a host, a user or NixOS is. You name your own nouns,
        so it configures NixOS, nix-darwin, home-manager, clusters, terraform or anything else you can model as Nix values.
        For reuse, `yen.lib.batteries` are functions from roles to a yen module: you give every name. Domain batteries,
        such as `yen.lib.batteries.nixos`, fill those roles with one domain's options.

        ${link "Documentation" "/"} · ${link "Getting started" "/start/getting-started/"} · [Reference fully-featured fleet](https://github.com/vic/yen/tree/main/templates/fleet) · [vic/vix on yen](https://github.com/vic/vix/tree/yen) · [Sponsor vic](https://dendritic.oeiuwq.com/sponsor)

        ## Four words

        - **Kinds**: your nouns, typed. `yen.kinds.host.fields.addr = lib.types.str;`
        - **Scopes**: where things live. `spawns` builds a tree from your data: a user under each host it is on.
        - **Aspects**: behavior, active where a predicate holds: a kind, an instance, another aspect, or any fact.
        - **Sinks**: where elements go. An element goes up to the nearest scope that collects it, and the sink reduces them.

        Data is queried, not merged: each read is a query on the files that answer it, so content in many files never
        overwrites itself, and an error is a record you can read.

        ## A fleet on one page

        Two environments, three NixOS hosts, a user on two of them, postgres placed by a fact (some host names it as its
        database), and a rule that holds across machines. Every line runs: these files are a tested template
        (plus a `hardware.nix` stub so NixOS evaluates).
      ''
      (docs.file "modules/kinds.nix")
      (docs.file "modules/data.nix")
      (docs.file "modules/behavior.nix")
      ''
        Ask it. The tree comes from the data:
      ''
      (docs.value (map (s: s.id) result.scopes))
      ''
        ## Change it safely

        An agent proposes a host in `lab` that uses the prod database. `yen.lib.stage` evaluates the fleet without and with
        the change, applies nothing, and refuses it with the rule it breaks:
      ''
      (docs.file "changes/api-in-lab.nix")
      (docs.value {
        inherit (staged) ok violations;
        added = staged.diff.scopes.added;
      })
      ''
        ## What else it does

        - **Graphs, Datalog and µKanren, in pure Nix**: deploy waves, well-founded models with proofs and why-not, and values
          synthesized under constraints (a free port, guest memory that fits). ${link "Ask and prove" "/query/queries/"}
        - **Agents as team members**: every answer is JSON-safe data. Changes are staged, checked by invariants, limited by
          grants that only narrow, and written as change programs. An MCP server answers agents. ${link "For agents" "/agents/agent-surface/"}
        - **Errors with fixes**: `code`, `path`, `got`, `want`, `fix`, and `near` for typos. ${link "Errors as data" "/principles/errors/"}
        - **Fast where it counts**: one nixpkgs per system across hosts, and trimmed NixOS module lists, with drvPath oracles
          that prove the systems are the same. ${link "Performance" "/perf/shared-pkgs/"}
        - **Every capability of Den, den-hoag and clan**, and the patterns of real fleets, each with a check, in the
          [reference fleet](https://github.com/vic/yen/tree/main/templates/fleet). ${link "From Den" "/migrate/from-den/"}

        ## Start
      ''
      (docs.sh "nix flake init -t github:vic/yen#one-page-fleet")
      ''
        Then read the ${link "documentation" "/"}: every page is a tested example. Coming from `configuration.nix`, a flake or Den?
        The ${link "migration guides" "/migrate/from-configuration-nix/"} build the same systems before and after.

        yen is made by [vic](https://github.com/vic), with love, as part of the [Dendritic ecosystem](https://dendritic.oeiuwq.com).
        If it helps you, please [sponsor vic](https://dendritic.oeiuwq.com/sponsor). Issues and pull requests are welcome:
        see [CONTRIBUTING.md](CONTRIBUTING.md).
      ''
    ];

  checks =
    {
      result,
      inputs,
      dir,
      engine,
      eq,
      yes,
      no,
      ...
    }:
    let
      s = engine.stage {
        base = {
          imports = [ (inputs.import-tree (dir + "/modules")) ];
          inherit inputs;
          inherit (inputs.nixpkgs) lib;
          yen.sinks = {
            inputs = { };
            lib = { };
          };
        };
        change = dir + "/changes/api-in-lab.nix";
      };
    in
    {
      ok = yes (result.check.ok);
      postgres-by-fact = {
        t1 = yes (result.active.postgres."fleet:main/env:prod/host:db");
        t2 = no (result.active.postgres."fleet:main/env:prod/host:web");
      };
      refused = {
        t1 = no (s.ok);
        t2 = eq (s.violations) ([
          [
            "bad"
            "db-same-env"
            "fleet:main/env:lab/host:api"
          ]
        ]);
      };
    };
  e2e =
    {
      flake,
      eq,
      yes,
      no,
      ...
    }:
    {
      account-on-box = yes (flake.nixosConfigurations.box.config.users.users.ana.isNormalUser);
      postgres = yes (flake.nixosConfigurations.db.config.services.postgresql.enable);
      fqdn = eq (flake.nixosConfigurations.web.config.networking.fqdn) ("web.example.com");
    };
}
