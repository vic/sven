# Yen: Nix fleets you can formally verify before deployment.

<!-- Generated from docs/examples/why/page.nix. Edit there, then run `nix run .#write-files` in docs/. -->


**Yen is a minimal pure-Nix language for verified fleet configurations**: no dependencies, no nixpkgs module system.
You describe your fleet as terms and the relationships between them. Yen answers queries about it: which systems to build,
verification errors, dependency graphs of who gives what to whom, and whether your invariant rules hold across all machines.

Yen is built on four concepts: **kinds**, **scopes**, **aspects** and **sinks**. The Yen kernel knows nothing about
NixOS, but it can describe fleets over any configuration domain: NixOS, nix-darwin, home-manager, clusters, terraform, k8s,
or anything else you can model as Nix values. You define your own domain language, and Yen uses it.


[Documentation](https://yen.oeiuwq.com/) · [Getting started](https://yen.oeiuwq.com/start/getting-started/) · [A fleet on one page](https://yen.oeiuwq.com/start/one-page-fleet/) · [Reference fleet](https://github.com/vic/yen/tree/main/templates/fleet) · [vic/vix@yen](https://github.com/vic/vix/tree/yen) · [Sponsor vic](https://dendritic.oeiuwq.com/sponsor)


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



```nix title="flake.nix"
{
  inputs.yen.url = "github:vic/yen";
  outputs = inputs: inputs.yen.lib.mkFlake ./modules/hello.nix;
}
```


Yen imposes no domain language, so you can define the nouns of your own world, how they relate to each other,
and how they contribute to the final Nix configuration.



```nix title="modules/hello.nix"
{ yen, ... }:
{
  # `inputs.yen.lib.mkFlake` expects this function to exist.
  # Here we ask for a **greetings** sink that will be used
  # for teaching purposes, as the output of our flake.
  yen.flake = { greetings, ... }: greetings;

  # In this flake we model translations of diffent human languages
  yen.kinds.language.fields.hello = yen.lib.is builtins.isString;

  # World is the container of all our human languages
  yen.kinds.world = {
    spawns.language = world: yen.language;
    # all greetings contributions get merged as attrsets
    sinks.greetings.reduce = yen.lib.reduce.merge;
  };

  # An aspect is configuration behaviour
  yen.aspects.hello = {
    # This predicate indicates where is `hello` active.
    # this can be a kind a particular instance of a kind or any predicate.
    at = yen.kinds.language;

    # This aspect contributes an element to the `greetings` sink.
    # Since `hello` is active for each language, it produces two entries.
    greetings =
      { language, ... }:
      {
        ${language.name} = language.hello;
      };
  };

  # define an instance of our world kind
  yen.world.earth = { };
  # and two languages with their respective field set.
  yen.language.en.hello = "Hello";
  yen.language.es.hello = "Hola";
}
```


The output of this flake looks like this:



```nix title="result.nix"
{
  en = "hello";
  es = "hola";
}
```


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
and values synthesized under constraints <sup>[docs](https://yen.oeiuwq.com/query/queries)</sup>.

µKanren-style logic programs let you synthesize configurations from constraints. For example, allocate a free port,
or compute a VM's memory so it takes only a percentage of its host.

Datalog facts describe invariants about your fleet. For example, you can state that a web server and its database
must be in the same region or environment.

```nix
# `facts.host` and `host.region` were derived here by Yen,
# it follows your own domain definitions.
let inherit (yen.facts.host); in
yen.invariants.db-same-region = { H, D, R }: {
  bad = H;
  pos = [ (host.db H D) (host.region H R) ];  # H uses D as its database, and lives in region R
  neg = [ (host.region D R) ];                # and D does not
};
```

Fields, aspects and variables are references, not strings: a typo is an evaluation error. A lab host that points at
the prod database gives `[ "bad" "db-same-region" "fleet:main/region:eu/host:api" ]`, and the fleet builds nothing until
it is fixed.

## Agents as first-class team members

Everything in Yen is expressed as a query, and every answer is JSON-safe data. Agents can propose changes to your
infrastructure, and those changes are verified **before** any file is edited. Changes are staged, checked against
invariants, limited by grants that can only narrow, and written as change programs. An MCP server answers agents and
lets them write only verified changes. <sup>[docs](https://yen.oeiuwq.com/agents/agent-surface)</sup>

## Errors are data

Errors are not throws. They are data that agents and humans can inspect, with **hints for fixes**: `code`, `path`,
`got`, `want`, `fix`, and `near` for typos. <sup>[docs](https://yen.oeiuwq.com/concepts/errors)</sup>

## Why Yen

- **Minimal surface.** The Yen language is minimal. It lets you define the things in your world, a tree built from your data,
  features that apply where a condition holds, and a place for each piece of configuration to go. <sup>[docs](https://yen.oeiuwq.com/start/overview/)</sup>
- **Domain agnostic.** Yen can configure anything Nix can: NixOS, nix-darwin, home-manager, clusters and more. Name the
  things in your world: hosts, users, services, or your own.
- **On par with advanced frameworks like Den.** Hosts, users, homes, includes, defaults, batteries, guests, roles, secrets,
  generated files. Moving from Den is easy. <sup>[docs](https://yen.oeiuwq.com/migrate/from-den/)</sup>
- **Queries, not merges.** Each value is a query on the files that declare it. Content spread over many files never
  overwrites itself, and two different answers are an error you can read. <sup>[docs](https://yen.oeiuwq.com/concepts/queried-not-merged/)</sup>
- **Less to evaluate.** Yen itself is about 1% of a host's evaluation. Sharing one nixpkgs per system instead of one per host
  saves about a third, and a check proves that every system is the same. <sup>[docs](https://yen.oeiuwq.com/perf/shared-pkgs/)</sup>
- **Mistakes are caught early, with a fix.** A typo gets a "did you mean". Every error says where it is, what was
  expected, and how to fix it. <sup>[docs](https://yen.oeiuwq.com/concepts/errors/)</sup>
- **Ask your fleet anything.** Graphs for deploy waves, cycles and impact; Datalog with negation; stored queries you name
  once and ask from Nix, the CLI, or an agent. <sup>[docs](https://yen.oeiuwq.com/query/queries/)</sup>
- **Values that solve themselves.** µKanren with finite domains, in pure Nix: a free port, guest memory that fits,
  relations that run backward. <sup>[docs](https://yen.oeiuwq.com/query/krn/)</sup>
- **Rules across machines.** Write a rule once, and a fleet that breaks it builds nothing. Each verdict comes with
  a proof that a small checker verifies, and a seal anyone can check again. <sup>[docs](https://yen.oeiuwq.com/query/invariants/)</sup>
- **Time and impact.** See what a host's elements reach, the fleet without one declaration, and instances valid at a
  given date. <sup>[docs](https://yen.oeiuwq.com/agents/history/)</sup>
- **Ready for agents.** An AI agent can ask about your fleet, stage a change, and see why it is refused, before
  anything is applied. Yen ships an MCP server and a skill that teaches agents to use it. <sup>[docs](https://yen.oeiuwq.com/agents/mcp/)</sup>
- **Just Nix.** Yen is built on Nix builtins with no dependencies. It provides two logic languages alongside its configuration kernel.
- **Tested and documented.** Every page you read is a tested example checked by CI, and all the docs are generated.

## Try it

```sh
nix flake init -t github:vic/yen#one-page-fleet
```

Then read [A fleet on one page](https://yen.oeiuwq.com/start/one-page-fleet/) and the [documentation](https://yen.oeiuwq.com/).

## Sponsor

Yen is made with love by [vic](https://github.com/vic). Years of work have gone into bringing formal verification
to reproducible Nix fleets in our agentic era, because correctness matters most here.
If Yen helps your business, your homelab, your team or your agents, please [sponsor vic](https://dendritic.oeiuwq.com/sponsor).
Issues and pull requests are welcome: see [CONTRIBUTING.md](CONTRIBUTING.md).

