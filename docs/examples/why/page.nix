let
  site = "https://yen.oeiuwq.com";
  link = text: path: "[${text}](${site}${path})"; # absolute: this page is also the repository README
  doc = path: "<sup>[docs](${site}${path})</sup>"; # a small link after a point, so the prose stays clean
  # the two hosts of variants/invariant.nix, as a caller outside the fleet names them: their identity
  web = {
    kind = "host";
    name = "web";
  };
  db = web // {
    name = "db";
  };
in
{
  title = "Why Yen";
  plainTitle = "Yen: Nix fleets you can formally verify before deployment.";
  description = "Yen is a cycle.js based language for Nix configurations";
  section = "start";
  order = 1;
  alsoAt = "../README.md"; # the same text is the repository README: plain markdown only

  body =
    { docs, variant, ... }:
    [
      ''

        **Yen is a minimal pure-Nix language for verified fleet configurations**: no dependencies, no nixpkgs module system.
        You describe your fleet as terms and the relationships between them. Yen answers queries about it: which systems to build,
        verification errors, dependency graphs of who gives what to whom, and whether your invariant rules hold across all machines.

        Yen is built on four concepts: **kinds**, **scopes**, **aspects** and **sinks**. The Yen kernel knows nothing about
        NixOS, but it can describe fleets over any configuration domain: NixOS, nix-darwin, home-manager, clusters, terraform, k8s,
        or anything else you can model as Nix values. You define your own domain language, and Yen uses it.


        ${link "Documentation" "/"} · ${link "Getting started" "/start/getting-started/"} · ${link "A fleet on one page" "/start/one-page-fleet/"} · [Reference fleet](https://github.com/vic/yen/tree/main/templates/fleet) · [vic/vix@yen](https://github.com/vic/vix/tree/yen) · [Sponsor vic](https://dendritic.oeiuwq.com/sponsor)


        ## The Cycle model

        Yen is designed around [Cycle.js](https://cycle.js.org) and other functional reactive programming principles.
        As in Cycle, an aspect (a behavior) is a function `sources -> sinks`. It sends requests through its `sinks` to its parent cycles
        to observe the world, and it gets their answers back through `sources`.

        For example, a user aspect can ask which host it lives on, or whether a service is enabled somewhere else in the fleet.
        Most of the time, aspects are simple and look like plain Nix configurations. They need no knowledge of the underlying query model.


        ## Main Concepts

        - **Kinds**: the nouns of the things in your fleet, and their typed fields.
        - **Scopes**: how kinds nest inside each other. `.spawns.` builds the nested cycles from your data: a user under each host.
        - **Aspects**: reactive behavior. `.at` sets a predicate that must hold for the behavior to be active: a kind, an instance of a kind, another aspect, or any custom predicate.
        - **Sinks**: data channels. A configuration element goes up to the nearest scope that collects a sink, and that scope decides how to reduce all the contributions.

        ## Annotated example

        Yen has no dependencies. It is built only on Nix `builtins`. This is the most basic flake
        that takes a single Yen module.

      ''

      (docs.file "flake.nix")

      ''

        Yen imposes no domain language, so you can define the nouns of your own world, how they relate to each other,
        and how they contribute to the final Nix configuration.

      ''

      (docs.file "modules/hello.nix")

      ''

        The output of this flake looks like this:

      ''

      (docs.file "result.nix")

      ''

        ## Design Principles

        Unlike the nixpkgs module system, where a type's `check` and `merge` are part of the same definition, Yen keeps data validation
        separate from the `reduce` (merge) strategy. Each sink boundary defines how data is collected or transformed. Data is queried
        instead of being merged into one global `config` attribute.

        Yen treats errors as data. Since every relationship and read between kinds is traceable, Yen can build a dependency graph
        showing what reads from what, and where the data comes from.

        From your definitions, Yen derives logic facts and relationships. You use them with logic variables to state invariants
        that must hold across the parts of your fleet before it can even be built. Think of them as formal constraints over
        services or fleet members.


        ## Two Logic Languages

        Yen ships two pure-Nix logic languages to help you deploy in waves: well-founded models with proofs, why-not explanations,
        and values synthesized under constraints ${doc "/query/queries"}.

        µKanren-style logic programs let you synthesize configurations from constraints. For example, allocate a free port,
        or compute a VM's memory so it takes only a percentage of its host.

        Datalog facts describe invariants about your fleet. For example, you can state that a web server and its database
        must be in the same region or environment.

      ''
      (docs.file "variants/region.nix")
      ''

        Fields, aspects and variables are references, not strings: a typo is an evaluation error. An `api` host in region `eu`
        that points at a database in `us` gives `[ "bad" "db-same-region" "fleet:main/region:eu/host:api" ]`, and the fleet
        builds nothing until it is fixed.

        ## Answers come with a reason

        Logic questions about your fleet get answers you can read. `result.check.why` gives the rules that make a violation
        true. `result.check.whyNot` works the other way. For an atom that is not true, it gives each rule with that head, and
        the body atoms that stop it. For an atom that is true, it gives nothing. A question is a literal, by reference:
        `result.check.bad.<invariant> host`, with the host an instance (or `{ kind; name; }` from outside the fleet).
      ''
      (docs.file "variants/invariant.nix")
      ''

        Here `web` breaks the rule, and `db` does not. The violation for `web`:
      ''
      (docs.value (variant "variants/invariant.nix").check.violations)
      ''
        `whyNot` for `db` says that no rule has this head. The desktop aspect is only active at `web`, so the rule
        is not even a candidate at `db`.
      ''
      (docs.value (
        let
          inv = (variant "variants/invariant.nix").check;
        in
        inv.whyNot (inv.bad.no-desktop-on-servers db)
      ))
      ''

        ## Values from constraints

        `yen.lib.krn` finds values that fit your constraints, and a relation can run backward.
      ''
      (docs.file "variants/ports.nix")
      (docs.value (variant "variants/ports.nix").reduced.greetings."world:earth".ports)
      ''
        `first` is one answer, and `count` is every answer.

        ## Checks before a change lands

        Yen checks the whole fleet before a change reaches a file. A rule is a function of its variables, and it names what it
        breaks. A rule can hold across machines, so a mistake that involves two hosts gets caught too. These are easy to make in a
        homelab: a desktop on a server, or two hosts with the same address.

        A change is staged before it is written. `yen.lib.stage` evaluates the fleet without the change and with it. `ok` is true
        only when nothing new is wrong. A grant made with `yen.lib.grant` limits the scopes a change may reach, and a grant can only narrow.

        Each verdict can come with a certificate. `yen.lib.datalog.checkCertificate` is a small checker. After evaluation,
        `result.check.certified` is true when the checker accepts the certificate and it states the same verdict. `result.check.seal`
        ties the verdict to hashes of the engine, the rules and the facts, so anyone can run `result.check.verify seal` again and get
        `{ ok = true; }`.

        ## Agents as first-class team members

        Everything in Yen is expressed as a query, and every answer is JSON-safe data. Agents can propose changes to your
        infrastructure, and those changes are verified **before** any file is edited. Changes are staged, checked against
        invariants, limited by grants that can only narrow, and written as change programs. An MCP server answers agents and
        lets them write only verified changes. ${doc "/agents/agent-surface"}

        ## How agents check a change

        An agent works on a Yen fleet through the MCP server in `mcp/`. The skill in `.claude/skills/yen-mcp/SKILL.md` gives the
        order of calls. The agent reads with `yen_schema` and `yen_check`, asks with `yen_why_not` and `yen_explain`, and stages a
        change with `yen_stage` before any file is written. A fleet passes `yen_check` only when `ok` is true, with no violations,
        no `incomplete` or `opaque` atoms, and `certified` true.

        From the fleet's working directory, run `nix run github:vic/yen?dir=mcp`. An MCP client starts the same server with
        the arguments `[ "run" "github:vic/yen?dir=mcp" ]`.

        The agent can show the staged answer to a person, with its violations, its diff and its refusals. A refusal with
        `class = "authority"` is not for the agent to fix. The agent tells the owner what it wanted to change, and why.

        ## Errors are data

        Errors are not throws. They are data that agents and humans can inspect, with **hints for fixes**: `code`, `path`,
        `got`, `want`, `fix`, and `near` for typos. ${doc "/principles/errors"}

        ## Why Yen

        - **Minimal surface.** The Yen language is minimal. It lets you define the things in your world, a tree built from your data,
          features that apply where a condition holds, and a place for each piece of configuration to go. ${doc "/start/overview/"}
        - **Domain agnostic.** Yen can configure anything Nix can: NixOS, nix-darwin, home-manager, clusters and more. Name the
          things in your world: hosts, users, services, or your own.
        - **On par with advanced frameworks like Den.** Hosts, users, homes, includes, defaults, batteries, guests, roles, secrets,
          generated files. Moving from Den is easy. ${doc "/migrate/from-den/"}
        - **Queries, not merges.** Each value is a query on the files that declare it. Content spread over many files never
          overwrites itself, and two different answers are an error you can read. ${doc "/principles/queried-not-merged/"}
        - **Less to evaluate.** Yen itself is about 1% of a host's evaluation. Sharing one nixpkgs per system instead of one per host
          saves about a third, and a check proves that every system is the same. ${doc "/perf/shared-pkgs/"}
        - **Mistakes are caught early, with a fix.** A typo gets a "did you mean". Every error says where it is, what was
          expected, and how to fix it. ${doc "/principles/errors/"}
        - **Ask your fleet anything.** Graphs for deploy waves, cycles and impact; Datalog with negation; stored queries you name
          once and ask from Nix, the CLI, or an agent. ${doc "/query/queries/"}
        - **Values that solve themselves.** µKanren with finite domains, in pure Nix: a free port, guest memory that fits,
          relations that run backward. ${doc "/query/krn/"}
        - **Rules across machines.** Write a rule once, and a fleet that breaks it builds nothing. Each verdict comes with
          a proof that a small checker verifies, and a seal anyone can check again. ${doc "/query/invariants/"}
        - **Time and impact.** See what a host's elements reach, the fleet without one declaration, and instances valid at a
          given date. ${doc "/agents/history/"}
        - **Ready for agents.** An AI agent can ask about your fleet, stage a change, and see why it is refused, before
          anything is applied. Yen ships an MCP server and a skill that teaches agents to use it. ${doc "/agents/mcp/"}
        - **Just Nix.** Yen is built on Nix builtins with no dependencies. It provides two logic languages alongside its configuration kernel.
        - **Tested and documented.** Every page you read is a tested example checked by CI, and all the docs are generated.

        ## Try it

        ```sh
        nix flake init -t github:vic/yen#one-page-fleet
        ```

        Then read ${link "A fleet on one page" "/start/one-page-fleet/"} and the ${link "documentation" "/"}.

        ## Sponsor

        Yen is made with love by [vic](https://github.com/vic). Years of work have gone into bringing formal verification
        to reproducible Nix fleets in our agentic era, because correctness matters most here.
        If Yen helps your business, your homelab, your team or your agents, please [sponsor vic](https://dendritic.oeiuwq.com/sponsor).
        Issues and pull requests are welcome: see [CONTRIBUTING.md](CONTRIBUTING.md).
      ''
    ];

  checks =
    {
      result,
      variant,
      eq,
      lib,
      ...
    }:
    let
      inv = (variant "variants/invariant.nix").check;
      p = (variant "variants/ports.nix").reduced.greetings."world:earth".ports;
      cmd = "nix run github:vic/yen?dir=mcp";
    in
    {
      result = eq result.flake (import ./result.nix);
      invariant = {
        violations = eq (inv.violations) ([
          [
            "bad"
            "no-desktop-on-servers"
            "fleet:main/host:web"
          ]
        ]);
        whyNot-holds = eq (inv.whyNot (inv.bad.no-desktop-on-servers web)) ([ ]);
        whyNot-candidate = eq (inv.whyNot (inv.bad.no-desktop-on-servers db)) ([
          {
            rule = null;
            reason = "no rule has this head";
          }
        ]);
      };
      ports-errors = eq ((variant "variants/ports.nix").errors) ([ ]);
      region = eq ((variant "variants/region.nix").check.violations) ([
        [
          "bad"
          "db-same-region"
          "fleet:main/region:eu/host:api"
        ]
      ]);
      mcp-run-line = {
        flake = eq (lib.hasInfix cmd (builtins.readFile ../../../mcp/flake.nix)) true;
        skill = eq (lib.hasInfix cmd (builtins.readFile ../../../.claude/skills/yen-mcp/SKILL.md)) true;
      };
      ports = {
        first = eq (p.first) ([
          {
            grafana = 8081;
            loki = 8082;
            prometheus = 8080;
          }
        ]);
        count = eq (p.count) (12);
      };
    };
}
