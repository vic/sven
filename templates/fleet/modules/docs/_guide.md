## What sven is

sven is a query language for Nix configurations. You declare data and behavior in plain Nix files. sven answers queries on them: the NixOS systems, the homes, the flake outputs, the errors, the graph.

sven is a small Nix file with no dependencies. It uses builtins only. It does not use nixpkgs, the module system or flakes. It never calls `throw`: an error is data that you query.

sven follows [Cycle.js](https://cycle.js.org): a component reads sources and writes sinks, and drivers answer the sinks. In Nix, laziness closes the loop. There is no `evalModules` fixpoint and no merge step. A value is computed only when something reads it.

This fleet is the reference example. It models the [Ren](https://github.com/vic/ren) fleet template, every capability of [Den](https://github.com/denful/den) and of den-hoag (Den on Gen), and the advanced cases of four real configurations (sini, swarsel, adda, vix). Every section below points to the file that shows it.

## Start

```nix
# flake.nix
{
  inputs.sven.url = "github:vic/sven";
  inputs.import-tree.url = "github:denful/import-tree";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
  outputs = inputs: inputs.sven.lib.mkFlake {
    imports = [ (inputs.import-tree ./modules) ];
    _module.args = { inherit inputs; inherit (inputs.nixpkgs) lib; };
  };
}
```

sven reads one module. A module is a path, a function or an attrset, with three keys: `imports`, `_module.args` and `sven`. sven does not know what `inputs` or `lib` are. You give them as args, and they flow down the `imports` tree to every file below.

A file in `modules/` looks like this:

```nix
{ sven, lib, ... }:
{
  sven.kinds.host.fields.addr = lib.types.str;
  sven.host.lb.addr = "10.0.1.1";
  sven.aspects.motd = {
    at = sven.kinds.host;
    nixos.environment.etc.motd.text = "managed by sven";
  };
}
```

Without flakes, call `(import ./sven).lib.eval module`. The result is a set of queries (see [Queries](#queries)).

## Kinds and instances

A kind is a type of thing: `host`, `user`, `environment`. Its `fields` are the data of each instance.

```nix
sven.kinds.host.fields = {
  addr = lib.types.str;                      # any value with `check` is a type
  environment = sven.kinds.environment;      # a kind is a type too: a ref to an instance
  buildHost = sven.lib.maybe lib.types.str;  # null by default
  settings.kernel.channel = sven.lib.maybe (sven.helpers.enum [ "lts" "latest" ]);
};
sven.host.lb = { addr = "10.0.1.1"; environment = sven.environment.prod; };
```

A type is anything with `check = value: bool`. `lib.types`, your own `sven.lib.is builtins.isString`, and kinds all work. sven has no type system of its own. `sven.lib.opt type default` and `sven.lib.maybe type` add a default. `sven.lib.derive type (self: …)` computes the default from the instance itself:

```nix
sven.kinds.host.fields.vpn = sven.lib.derive lib.types.str (self: "vpn-${self.name}");
```

Fields are strict. A missing field, an unknown field, a failed check, or a string where a ref goes is an error record. The read gives `null`, and evaluation continues.

## Data is queried, not merged

Two files can declare types at two paths of one field. sven does not merge them. A read of a path is one query on the files that answer that path.

```nix
# features/zfs.nix
sven.kinds.machine.fields.settings.zfs.arcMax = sven.lib.maybe lib.types.int;
# features/k3s.nix
sven.kinds.machine.fields.settings.k3s.role = sven.lib.opt lib.types.str "agent";
```

A read of `host.settings.k3s.role` looks at the instance first, then at the type defaults, then checks the value. It never touches `zfs.nix`. Compare: a nixpkgs `submodule` runs one more `evalModules` for each value.

A cascade is a list in your order. `sven.lib.cascade path xs` gives the first non-null value along `xs` ([sini/settings.nix](modules/sini/settings.nix)):

```nix
setting = path: h: sven.lib.cascade path ([ h ] ++ h.environment.delegates ++ [ h.environment ]);
```

## Scopes: where things live

A scope is one instance at one place in a tree. The root kind has `spawns` and no kind spawns it. `spawns.<kind>` gives the children of a scope:

```nix
sven.kinds.environment.spawns.host = s: lib.filterAttrs (_: h: sven.lib.same h.environment s) sven.host;
```

The identity of a scope is its path: `fleet:main/environment:prod/host:lb`. One name can live in two places. In this fleet, `host:lb-minimal` lives under `host:lb` ([swarsel/variants.nix](modules/swarsel/variants.nix)). Names need not be unique.

A kind that no kind spawns is data: `group`, `channel`, `secret`. Its instances have no scope, and refs to them still work.

Siblings sort by the `order` sink (default `0`), then by key. A parent comes before its children.

## Aspects: behavior at scopes

An aspect is active at every scope where its `at` predicate holds. It gives elements to sinks by key.

```nix
sven.aspects.nginx = {
  at = [ sven.host.web-1 sven.host.web-2 sven.aspects.status ];  # a list is "any"
  nixos.services.nginx.enable = true;   # one element to the `nixos` sink
  backends = { host, ... }: host.addr;  # one element to the `backends` sink
  persist = "/var/lib/nginx";
};
```

A predicate is a function `scope: bool`. A kind ref, an instance ref, an aspect ref and a list are predicates too. Combine them with `sven.lib.all`, `not`, `within` (a proper ancestor holds) and `has` (a child holds).

`at` from several files is a union. To replace an aspect at one scope, put `not` in its `at` and write your own aspect ([features/motd.nix](modules/features/motd.nix)). A value in `at` that is not a predicate (a string, a number) is an error record, not a silent `false`.

One aspect can live in several files. Data under one key merges. Functions under one key each apply: two files that write `nixos = { … }: …` for the same aspect give two elements.

An aspect is active only at the scope where `at` holds. It never flows down to children: a host profile does not reach the host's guests.

Static content counts once per receiver. An aspect active at a host and at its users, with the same static `nixos` value, lands once on the host. Content that names the scope (`{ user, ... }:`) lands once per scope.

This rule decides how you write a value for a fleet-wide sink. A static value from many machines arrives once: use it for data that all machines share (a shared vars generator). A function value arrives once per machine: use it for data that each machine owns (a per-machine generator, `{ scope, ... }: …`). See [clan/vars.nix](modules/clan/vars.nix).

Structure can depend on presence: a `spawns` function can ask `sven.lib.holds sven.aspects.role-server s` at the parent ([den/presence-structure.nix](modules/den/presence-structure.nix)).

Each scope computes each aspect ref once, so aspects that read aspects cost linear time, however deep they nest. Refs can form cycles. A cycle through `not` has no answer: the aspects on it are undefined, as in the well-founded semantics of logic programs. They are not active, and the `undefined` query lists them. A cycle with no `not` (`p` where `q`, `q` where `p`) has no founded support, so it is false.

## Sinks: where elements go

A sink on a kind collects elements and reduces them:

```nix
sven.kinds.host.sinks.persist = { reduce = sven.lib.reduce.set; of = lib.types.str; };
```

| Reduce | Value | Error |
|---|---|---|
| `list` (default) | the elements in scope order | none |
| `set` | the elements without duplicates | none |
| `one` | the single element | 0 or 2+ elements |
| `merge` | a deep attrset | two different leaves at one path |
| `entries` | `[ { from; value; } ]`: the giving scope comes with each value | none |

An element goes to the nearest ancestor-or-self scope that has the sink and where the sink's `at` holds. A user under host `lb` gives `os`. The user has no `os` sink, the host has one, so the element goes to `lb`. The same user under a mac goes to the mac.

A sink's other keys give elements to other sinks. They run at the receiver, with the receiver's args:

```nix
sven.kinds.host.sinks.os.nixos = { os, ... }: { imports = os; };        # os feeds nixos: one `os` for NixOS and darwin
sven.kinds.guest.sinks.nixos.nixos = { guest, nixos, ... }: {           # its own name: a forward, strictly up
  microvm.vms.${guest.name}.config.imports = nixos;
};
```

A sink that nobody reads is not an error. Nothing happens. A sink with no keys is a wall: `sven.kinds.home.sinks.os = { }` keeps a home's elements away from the host above it.

A sink's `reduce` can be any function `[ { from; value; } ] -> { value; errors; }`. Write your own when the merge order is the point: per-key strategies with provenance ([hoag/ci.nix](modules/hoag/ci.nix)), ranked layers ([hoag/settings.nix](modules/hoag/settings.nix)), dedup of claims, an export store where a member can only write its own scope ([clan/inventory.nix](modules/clan/inventory.nix)). The engine sets `from`. An element cannot say where it comes from, so a scope cannot write for another.

Give errors and warnings as data. An aspect key `errors` adds records to the `errors` query. A sink such as `warnings` (with `reduce.list`) holds messages that do not fail the fleet ([clan/inventory.nix](modules/clan/inventory.nix): a tag that matches no machine).

Do not give a sink the name of a field or an arg. A sink `tags` and a field `tags` read as one arg. In this fleet, clan tags are the field `labels` for that reason.

The `out` sink of the root is the flake. `sven.flake = { out, ... }: out;` gives it.

## Args: reading data

An element can be a function with named args. sven fills the args it knows:

| Arg | Value |
|---|---|
| a kind name (`host`, `environment`) | the nearest ancestor-or-self scope of that kind |
| a sink name (`backends`, `persist`) | the reduced value of that sink at its nearest receiver |
| `scope` | the scope itself |

Other args (`pkgs`, `lib`, `config`) stay open. The element is then a module function for NixOS or home-manager, with sven's args already filled.

If an arg has no answer, the element is not given, and `errors` lists it. `{ cluster ? null, ... }` makes the arg optional. A bare `final: prev:` is an error: wrap it as `{ ... }: final: prev: …`.

## The cycle form

The keys above give one element each. For 0 to n elements, or to ask the tree for data, write a component:

```nix
sven.aspects.kernel = {
  at = sven.kinds.host;
  cycle = { tree, ... }: {
    tree = [ { category = "env"; nearest = sven.kinds.environment; } ];   # a request
    nixos = map (env: { boot.kernelParams = [ "env=${env.name}" ]; }) (tree.select "env");
    errors = [ ];                                                          # a component can report errors
  };
};
```

Tree requests: `nearest = <kind>`, `parent = true`, `children = <predicate>`, `scopesOf = <instance>`, `holds = <predicate>`.

## Queries

`sven.lib.eval module` gives queries, not one value:

| Query | Answer |
|---|---|
| `errors` | `[ { error; from; } ]`, empty when the fleet is valid |
| `graph` | `{ scopes; edges; }`: every scope and every routed element |
| `scopes` | the scopes in order |
| `active` | aspect, then scope id, then `true` or `false` |
| `undefined` | `[ { aspect; scope; } ]`: aspects that `at` cannot decide, because of a cycle through `not` (`a` where not `b`, `b` where not `a`). They are not active. |
| `reduced` | sink, then receiver id, then the value |
| `flake` | the answer of `sven.flake` |

`sven.lib.graph` is readable inside the fleet. Each edge has `sink`, `from`, `to` and `origin` (the aspect that gave the element), so "which aspects reach this host" is a query, not a registry. The diagrams and tables at the end of this README come from `graph`, the kind declarations and sink values ([docs/readme.nix](modules/docs/readme.nix)): the fleet map, the kind tree, sink forwarding, pools, clan instances, vars generators and the deploy order.

## Graphs, Datalog and krn

Fleet data is plain Nix, so a question about it is a function. sven ships three libraries for the hard ones. Each is builtins only, total, and gives the same answer whatever the file order.

**`sven.lib.graphs`** works on `succ`, an attrset from a node to its successors: `reach`, `reachers`, `transpose`, `topo` (a cycle is data: `{ ok = false; stuck; }`), `layers`, `sccs`, `cycles`, `shortest`, `paths`. [hoag/relations.nix](modules/hoag/relations.nix) builds the deploy waves, the dependents and the impact of losing a host, and gives an error for a dependency cycle:

```nix
dependsOn = lib.mapAttrs (_: h: map (d: d.name) h.dependsOn) hosts;
deployWaves = G.layers dependsOn;                                 # [ [ "lb" ] [ "web-1" "web-2" ] [ "stage" ] ]
impact = lib.genAttrs (lib.attrNames hosts) (G.reachers dependsOn); # lb down: stage, web-1, web-2 break
```

**`sven.lib.datalog`** solves ground rules with negation, `{ head; pos; neg; }`. You ground the rules with Nix (one per host). `wfs` gives the well-founded model (true, false, undefined; no strata). `stable` gives the stable models: a choice. `why` gives the rules that prove an atom. [query/datalog.nix](modules/query/datalog.nix) is a serving policy: a host serves when it runs nginx and is not drained. A host is drained when it is in maintenance or the host it depends on is down. The database primary is a choice between two hosts. An atom the policy leaves undefined is an error.

```nix
{ head = "serves:${n}"; pos = [ "web:${n}" ]; neg = [ "drained:${n}" ]; }
{ head = "drained:${n}"; neg = [ "up:${d.name}" ]; }              # for each host n depends on
{ head = "primary:lb"; neg = [ "primary:web-1" ]; }                # and the other way round: two stable models
```

**`sven.lib.krn`** is µKanren with constraints: logic variables, unification over attrsets, lists and scalars (with an occurs check), and goals that run in both directions. It synthesizes values that meet constraints.

| Goal | Meaning |
|---|---|
| `eq u v`, `fresh ({ a, b }: …)`, `freshNamed names (vs: …)`, `disj`, `conde`, `project` | µKanren: unify, new variables, any of, clauses, read a value |
| `neq u v` | `u` and `v` never unify. The store keeps the constraint, so its place in the goal list does not matter. |
| `dom x [ … ]`, `infd xs lo hi` | finite domains |
| `lefd`, `ltfd`, `plusfd x y z`, `neqfd`, `distinctfd xs` | propagation over domains, to a fixpoint after every change |
| `label xs` | enumerate the values left, smallest domain first |
| `nil`, `cons h t`, `appendo`, `membero`, `fromList`, `toList` | relational lists as cons cells, as in Scheme: a list of unknown length grows, and `appendo` runs in every direction |
| `facto rows pattern` | a table of facts |
| `run n`, `runAll`, `runC n` | answers; `runC` adds the constraints left on fresh variables (`{ value; neq; dom; }`) |

[query/krn.nix](modules/query/krn.nix) uses them on fleet data. Each app on lb gets a port in its range: all different, and prometheus before grafana. The same relation, run backward, answers which apps can take port 8081. Each guest on stage gets memory in its range, and the guests' sum plus the host's reserve fits its RAM. A join over host records places each host's database:

```nix
portsRel = h: q: freshNamed h.apps (vs: [ (infd (lib.attrValues vs) 8080 8083) (distinctfd (lib.attrValues vs)) (ltfd vs.prometheus vs.grafana) (eq q vs) (label (lib.attrValues vs)) ]);
# [ { grafana = 8081; loki = 8082; prometheus = 8080; } ]
memRel: (plusfd 0 ci s0) (plusfd s0 build s1) (lefd s1 (ram - reserve))   # running sums of the guests
runAll (q: fresh ({ env, d, own }: [ (facto hosts { name = "web-1"; inherit env; db = own; }) (facto hosts { name = d; inherit env; db = true; }) (eq q d) ]))
```

A search with no answer gives `[ ]`. Give an error record then, as `port-synthesis` and `memory-synthesis` do. krn has no constraints over terms other than `neq` (no `absento`), and `appendo` with two unknown lists enumerates without end: use `run n`.

## For agents: ask, prove, change

An agent that manages this fleet works through queries. Every answer is data that `builtins.toJSON` can print. `query.nix` gives them on the command line, for example the `agent` attribute with `--json`.

| Query | Answer |
|---|---|
| `schema` | every kind (fields with type names and defaults, spawns, sinks with their reduce strategy), every aspect (keys, files, how many scopes) and every invariant |
| `agent` | `schema`, `errors`, `check` and counts, JSON-safe |
| `context id { maxEdges; maxAspects; }` | one scope: parent, children, active aspects, the elements it gives and receives, its errors. Each list says `truncated = { shown; of; }` |
| `explain aspect id depth` | why an aspect is active, inactive or undefined at a scope: a trace of its `at` (true, false or null at each node), what it gives, its files. Past the depth, `kids = "cut"` |
| `declaredIn path` | the files that answer a declaration path, in file order |
| `facts` | the fleet as ground atoms: `kind:K:ID`, `has:ASPECT:ID`, `edge:SINK:FROM:TO`, `error:CODE:FROM` |
| `check` | the invariants: `violations`, `incomplete`, `ok`, `why atom` |

An unknown aspect or scope gives an error record with `near`: the names it was probably meant to be.

**Error records.** Each error has `error` and `from` for people, and `code`, `path`, `got`, `want`, `fix`, `class` and `near` for agents. `class` is `fixable` (an edit to the data fixes it) or `authority` (no edit by this author can).

```nix
{ code = "check"; path = [ "port" ]; got = 70000; want = "Port"; fix = "give port a value of type Port"; class = "fixable"; from = "host:a"; }
{ code = "unknown-field"; path = [ "prot" ]; near = [ "port" ]; … }
```

**Invariants.** `sven.invariants.<name>` gives Datalog rules over the facts ([agent/invariants.nix](modules/agent/invariants.nix)). A true `bad:` atom is a violation. An undefined one (a cycle through `not`) is `incomplete`, never a pass.

```nix
sven.invariants.attic = { scopes, ... }: map (s: { head = "bad:attic-on-mac:${s.id}"; pos = [ "has:attic:${s.id}" ]; }) (lib.filter (s: s.kind == "mac") scopes);
```

**Changes go through `stage`.** `sven.lib.stage { base; change; rejected ? [ ]; grant ? null; }` evaluates the fleet without and with the change. Nothing is applied. It returns the new errors, the new violations, a diff (scopes, routed elements, active aspects), the change's `sha` and the `refused` list. `ok` is true only when nothing new is wrong. A change in `rejected`, and an element outside the grant, are refused with `class = "authority"`. `render` is the change as JSON, so it can be read back and staged again.

```nix
sven.lib.stage { base = fleet; change = { sven.aspects.attic.at = [ { kind = "mac"; name = "studio"; } ]; }; }
# ok = false; violations = [ "bad:attic-on-mac:…/mac:studio" ]; diff.active.added = [ "attic@…/mac:studio" ]
```

**Proofs and why-not.** `sven.lib.datalog` adds `proof rules model atom` (a proof tree; a positive cycle shows `cycle = true`), `whyNot rules model atom` (per rule: the `missing` positive atoms, the `blocking` negative ones, the undefined ones) and `judge rules a notA` (`supported`, `refuted`, `both`, `neither` or `unknown`). [query/datalog.nix](modules/query/datalog.nix) gives `out.serving.whyNot.<host>` and judges the database primary: `unknown`, a choice the policy leaves open.

**Knowledge packs.** `sven.lib.rdf.share r` gives the eval result as sorted N-Triples with a sha256 and a count: scopes, kinds, parents, active aspects, every routed element as a node with its origin, and errors. The same fleet gives the same hash in every file order, so two revisions compare by hash first. [agent/rdf.nix](modules/agent/rdf.nix) packs the routing graph as `out.rdfPack`.

**Stored queries.** `sven.queries.<name> = { host, r }: …` names a question. `r` is the eval result; the other formal args are its parameters, required unless they have a default. `r.queries` lists them with `required` and `optional`, and `r.ask name args` answers, or gives an error record for an unknown query, a missing parameter or an unknown one ([agent/queries.nix](modules/agent/queries.nix)).

**What else breaks, and what if it were gone.** `r.impact id { hops; sinks; max; }` follows routed elements from a scope, by depth, with `truncated`. `sven.lib.without { files; path; args; }` evaluates the fleet without the files that declare `path`: a whole file goes, there is no hook to remove part of one.

**History and valid time.** `sven.lib.asOf { url; rev; module; }` evaluates the fleet at a git revision; `sven.lib.history { url; revs; module; }` lists each revision with the field changes from the one before (`diffData` over `r.data`). Valid time is data: an instance with `validFrom` or `validTo` holds at a date the caller passes, `sven.lib.validAt "2026-11-15"`. Pure evaluation has no clock.

**Labels.** `sven.labels."agent/" = { trust = 1; }` labels the content of files whose path contains `agent/`. An aspect declared in several files takes the lowest trust of them (the meet). `r.labels` gives each aspect's label and `r.floor 3` every routed element of an aspect below trust 3, with the file.

**A knowledge pack per revision.** An agent that keeps a store such as quipu knots `sven.lib.rdf.share r` into a named graph under one snapshot key, with `replace_snapshot`. Each revision replaces the last; the old one stays readable by transaction:

```
SELECT ?name WHERE { ?s rdf:type <https://sven.dev/fleet/kind/host> ; <https://sven.dev/fleet/sven/name> ?name }
# at the first revision's tx: db, web.   Now: web.
```

**Bounded search.** A krn query an agent writes must stop. `sven.lib.krn.runFuel n fuel f` and `runAllFuel fuel f` count each search step and return `{ answers; complete; }`: `complete = false` means "bounded", never "no answer". `maximize fuel measure f` gives `{ best; value; complete; count; }`; a best found under `complete = false` is not proven optimal. [query/krn.nix](modules/query/krn.nix) gives guest memory by `maximize` with `ramFuel` steps; a search that runs out of fuel is an error record.

**Shapes.** `sven.lib.rdf.shacl r` gives SHACL shapes from the schema: one node shape per kind with scopes, `sven:name` required, `sven:parent` of the spawning kind, each field at most once, and `sh:class` for ref fields. The pack types every instance, so a ref meets its class. quipu's validator accepts the pack of a fixture fleet and reports one `sh:class` violation for a ref to a missing instance.

**An MCP server.** `templates/fleet/mcp/sven-mcp.sh` answers agents over stdio (JSON-RPC, MCP). Its 14 tools: `sven_schema`, `sven_check`, `sven_context`, `sven_explain`, `sven_errors`, `sven_declared_in`, `sven_export` (the knowledge pack; the agent decides whether to store it), `sven_stage` (a change as JSON, in quarantine), `sven_queries` and `sven_ask` (stored queries, the synthesis ones included), `sven_impact`, `sven_labels` (with `floor`), `sven_why_not` (an atom's why and why-not) and `sven_program` (a change program, validated and dry-run). Each answer is `{ complete; result }` or `{ complete = false; error }`; a timeout is never an empty answer. Arguments reach Nix through a file and `builtins.fromJSON`, never through string interpolation. `mcp/test.sh` drives it. `nix run .#sven-mcp` from the fleet directory runs it as a flake app ([agent/mcp.nix](modules/agent/mcp.nix)): it serves the fleet in the working directory, and its flake ref comes from the git top (`SVEN_FLAKE` overrides it).

**Safe between machines, before deploy.** Facts include field values: `val:FIELD:ID:VALUE` and `ref:FIELD:ID:KIND:NAME`. Invariants over them hold across machines ([agent/invariants.nix](modules/agent/invariants.nix)): a host's database is in its own environment (`db-same-env`), no two machines share an address (`unique-addr`), and a host never depends on a host in a less trusted environment (`trust-order`). A staged change that breaks one is refused with the atom, and `check.whyNot` / `check.proof` explain an answer.

**Change programs.** `sven.lib.program` writes a change as data ops: `set`, `ref`, `place` and `new`. `validate r prog` checks it against the schema (with `near`), `toModule` makes the module, `dryRun { base; prog; }` validates and stages it, and `render` gives JSON. An agent writes a program, not Nix code.

**Install order.** The stored query `installOrder { instance }` gives the waves of a clan service instance: the servers first, then the clients ([agent/queries.nix](modules/agent/queries.nix), `sven.lib.graphs.layers`). For the backup instance: `[ [ "lb" ] [ … every client … ] ]`.

**Synthesis, checked.** Stored queries in [agent/synthesis.nix](modules/agent/synthesis.nix) answer with values that already meet the rules. `freePort { host }` lets krn pick a port no app on the host uses. `placeDb { host }` joins host records to find the database hosts of its environment. `safeHostsFor { aspect; env }` stages the aspect on each machine of the environment and returns where it is safe, and why the others are refused:

```nix
r.ask "safeHostsFor" { aspect = "attic"; env = "staging"; }
# { safe = [ "stage" ]; refused.studio = [ "bad:attic-on-mac:fleet:main/environment:staging/mac:studio" ]; }
```

**Grants only narrow.** `sven.lib.grant { scopes = [ id prefixes ]; sinks ? null; }` says where an agent may give elements. `narrow g h` keeps what both allow. No function makes a grant wider. A staged change that gives an element outside its grant is refused.

## Patterns in this fleet

| Pattern | From | File |
|---|---|---|
| hosts from JSON, refs from names | Ren | [hosts/inventory.nix](modules/hosts/inventory.nix) |
| users on machines from nested group grants | Ren, Den | [helpers.nix](modules/helpers.nix), [topology/access.nix](modules/topology/access.nix) |
| one `os` sink for NixOS and darwin | Ren #76 | [platforms/nixos.nix](modules/platforms/nixos.nix), [platforms/darwin.nix](modules/platforms/darwin.nix) |
| microvm guest forwards into its host | Ren, Den | [platforms/microvm.nix](modules/platforms/microvm.nix) |
| a diamond lands once per scope | Den #468 | [features/web.nix](modules/features/web.nix) |
| substitute with `not` | Den | [features/motd.nix](modules/features/motd.nix) |
| a check that reads a built system | Ren #60 | [topology/systems.nix](modules/topology/systems.nix) |
| specialisations as a variant kind | Den | [platforms/variants.nix](modules/platforms/variants.nix) |
| deterministic ids from sorted names | Den | [den/ids.nix](modules/den/ids.nix) |
| a standalone home that reads its host's data | Den #739 | [den/standalone-home-on-host.nix](modules/den/standalone-home-on-host.nix) |
| fan-out: every user × every pet (cartesian), toys of each pet (transitive), landing at the host | Den | [den/patterns.nix](modules/den/patterns.nix) |
| context enrichment: a sink is context (`isNixos`, then `platform`) | Den | [den/patterns.nix](modules/den/patterns.nix) |
| host-written home content for users who opt in, run in the user's context | Den host-aspects | [den/patterns.nix](modules/den/patterns.nix) |
| broadcast: the sender tags who receives | Den pipes | [den/patterns.nix](modules/den/patterns.nix) |
| a pipeline stage between producers and consumers | Den pipes | [den/patterns.nix](modules/den/patterns.nix) |
| one class into both NixOS and home-manager, and per-user home classes (`classes = [ maid ]`) | Den | [den/patterns.nix](modules/den/patterns.nix), [den/custom-classes.nix](modules/den/custom-classes.nix) |
| a value that reads its producer's realized config | Den #713 | [den/patterns.nix](modules/den/patterns.nix) |
| structure from presence: a child scope only where an aspect holds | Den #525 | [den/presence-structure.nix](modules/den/presence-structure.nix) |
| discovery: k3s nodes per cluster, ingest across environments | sini | [sini/clusters.nix](modules/sini/clusters.nix) |
| recursive kinds: domains under domains | sini | [sini/domains.nix](modules/sini/domains.nix) |
| conditional receivers: terranix, unifi | sini | [sini/network.nix](modules/sini/network.nix) |
| a mesh: each host reads its peers, drops itself | sini | [sini/mesh.nix](modules/sini/mesh.nix) |
| settings cascade with delegation | sini | [sini/settings.nix](modules/sini/settings.nix) |
| tags from active role aspects | sini | [sini/roles.nix](modules/sini/roles.nix) |
| one sink name on three kinds | sini | [sini/secrets.nix](modules/sini/secrets.nix) |
| a trust filter on the reader side | sini | [sini/xmsg.nix](modules/sini/xmsg.nix) |
| devshell, formatter, hooks: sink to sink | sini | [sini/flake.nix](modules/sini/flake.nix) |
| access by labelled groups: machine grants and gates, SSO-only users | sini | [topology/access.nix](modules/topology/access.nix), [sini/services.nix](modules/sini/services.nix) |
| an allow-list joined from three fleet pools, with an error for a client that has no address | sini | [sini/services.nix](modules/sini/services.nix) |
| first node starts the cluster, the others join | sini | [sini/clusters.nix](modules/sini/clusters.nix) |
| two pools joined by host, in the cluster's environment; a guest's intent read by its parent | sini | [sini/joins.nix](modules/sini/joins.nix) |
| aspect factories; an aspect checked alone with stand-in args; one DNS edge at most | sini | [sini/joins.nix](modules/sini/joins.nix) |
| merge strategy per key with provenance and refs; claim dedup; negation; demand cascade; shadowing query; suppression chain | den-hoag CI | [hoag/ci.nix](modules/hoag/ci.nix) |
| service instances × roles, perInstance and perMachine, layered typed settings, contract errors | clan | [clan/inventory.nix](modules/clan/inventory.nix), [clan/services.nix](modules/clan/services.nix) |
| exports: scoped by the engine, allow-listed per service, read across services, overridden by the owner | clan | [clan/inventory.nix](modules/clan/inventory.nix), [services/borg.nix](services/borg.nix) |
| vars: generator graph, shared or per machine, a deploy plan as data, secret-read guard | clan | [clan/vars.nix](modules/clan/vars.nix) |
| machines from directories, a service from outside `modules/` | clan | [clan/vars.nix](modules/clan/vars.nix), [services/borg.nix](services/borg.nix) |
| deploy waves, impact of losing a host, a dependency cycle as an error (`sven.lib.graphs`) | den-hoag | [hoag/relations.nix](modules/hoag/relations.nix) |
| a serving policy with maintenance, drain by dependency, a primary chosen by stable models (`sven.lib.datalog`) | Gen | [query/datalog.nix](modules/query/datalog.nix) |
| port allocation, guest memory, database placement, a query run backward (`sven.lib.krn` with finite domains) | µKanren, CLP(FD) | [query/krn.nix](modules/query/krn.nix) |
| one machine, two builds | swarsel | [swarsel/variants.nix](modules/swarsel/variants.nix) |
| one machine writes config into another, and fleet globals | swarsel | [swarsel/distributed.nix](modules/swarsel/distributed.nix) |
| aspects exported as `nixosModules` | swarsel, Den | [swarsel/exports.nix](modules/swarsel/exports.nix) |
| service domains into a reverse proxy, and flake templates | adda | [adda/services.nix](modules/adda/services.nix) |
| a child kind declared in another file, and feature gates | vix | [vix/editors.nix](modules/vix/editors.nix) |
| secrets as a data kind | vix | [vix/secrets.nix](modules/vix/secrets.nix) |

### `osConfig`: a home-manager module that reads its host

Each host gives its realized NixOS config to an `osConfig` sink. A home-manager module names `osConfig` like any sink arg. `pkgs` stays open, so home-manager fills its own `pkgs`:

```nix
sven.kinds.host.sinks.osConfig.reduce = sven.lib.reduce.one;
sven.aspects.os-config = {
  at = sven.kinds.host;
  osConfig = { host, out, ... }: out.nixosConfigurations.${host.name}.config; # lazy
};
sven.aspects.editors = {
  at = sven.lib.all [ sven.kinds.user (sven.lib.within sven.kinds.host) ];
  homeManager = { osConfig, pkgs, ... }: {
    home.sessionVariables.EDITOR_HOST = osConfig.networking.hostName;
    home.packages = [ pkgs.nano ];
  };
};
```

The same aspect works for a user in a host's NixOS (`alice` on `lb`) and for a standalone home under a host (`alice@stage`). The e2e checks `os-config-nested` and `os-config-standalone` prove it ([den/os-config.nix](modules/den/os-config.nix)).

### Den #739: a standalone home that reads host data

In [den#739](https://github.com/denful/den/discussions/739), a Den user wants host data (a monitor) in a standalone home `tux@igloo`. Den pipes the data to a home-manager module home only.

In sven, where a scope lives (`spawns`) and what it builds (`out`) are separate. The home `alice@stage` lives under host `stage`:

```nix
sven.kinds.host.spawns.home = s: lib.filterAttrs (_: h: sven.lib.same h.on s) sven.home;
sven.home."alice@stage" = { user = sven.user.alice; on = sven.host.stage; /* … */ };
sven.aspects.monitor-env.homeManager = { monitor ? null, ... }: { home.sessionVariables.MONITORRES = monitor.resolution; };
```

The home reads stage's `monitor` sink like any child. It still builds its own `homeConfigurations."alice@stage"`. Its `os` sink is a wall, so its users do not change stage's NixOS.

## sven, Den and Den on Gen

[Den](https://github.com/denful/den) has 1,365 CI tests in 289 files. Every one was read for the usage pattern it pins ([vic/den-patterns.md](https://github.com/vic/sven/blob/main/vic/den-patterns.md): 168 patterns). [den-hoag](https://github.com/sini/den-hoag), Den's next version on the [Gen](https://github.com/sini/gen) libraries, has 18 laws. This fleet shows each of their capabilities with sven's four words. Every row has a check in `tests.nix`.

| Den / den-hoag | sven | File |
|---|---|---|
| `den.default`, schema includes, batteries | an aspect with `at = sven.kinds.<kind>` | [den/batteries.nix](modules/den/batteries.nix) |
| includes, excludes, substitute, instance-side includes | `at` with aspect refs, `not`, `at` from any file | [features/motd.nix](modules/features/motd.nix), [sini/roles.nix](modules/sini/roles.nix) |
| custom classes, chained forwards (hjem, maid) | a user sink whose keys feed other sinks | [den/custom-classes.nix](modules/den/custom-classes.nix) |
| `hasAspect`, projected `hasAspect` | `sven.lib.holds`, and `graph` edges with `origin` | [sini/roles.nix](modules/sini/roles.nix) |
| a policy gated on `hasAspect` that creates structure (#525) | `spawns` that reads `holds` at the parent | [den/presence-structure.nix](modules/den/presence-structure.nix) |
| quirks and pipes: collect, expose, broadcast, provenance | a sink at a common ancestor with `entries`, and a filter in the reader | [sini/clusters.nix](modules/sini/clusters.nix) |
| a value that reads a realized config (#713, `osConfig`) | an `osConfig` sink that each host gives from `out.nixosConfigurations.<host>.config`, lazily | [den/os-config.nix](modules/den/os-config.nix), [den/standalone-home-on-host.nix](modules/den/standalone-home-on-host.nix) |
| settings layers with authority, the projects facet (A8, A14) | a sink with your own reduce | [hoag/settings.nix](modules/hoag/settings.nix) |
| claim and provide, "who claims me" | an `entries` sink and a reader filter | [hoag/claims.nix](modules/hoag/claims.nix) |
| collectors: an aggregate with its own content | a `hive` kind that selects its members | [hoag/collectors.nix](modules/hoag/collectors.nix) |
| relations and the query calculus (`rel*`, layers) | plain Nix over ref fields, with `genericClosure` | [hoag/relations.nix](modules/hoag/relations.nix) |
| permutation-stable output (A12), per-member laziness (A17) | file order never changes a result, and sinks are lazy per receiver | `tests.nix`: `den-permutation-stable`, `den-sibling-laziness` |
| class-share (A18): the config every member of a class shares is built once, gated against the full build | the core is the elements equal at every host; each host's shared build has the same toplevel `drvPath` as its full build | [hoag/class-share.nix](modules/hoag/class-share.nix) |

The den-hoag CI (175 test files and 57 Den behavior tests) gives 119 capabilities ([vic/hoag-ci-patterns.txt](https://github.com/vic/sven/blob/main/vic/hoag-ci-patterns.txt)): 92 have a check here, 25 are den-hoag mechanisms with no effect for a fleet author (strata, codomain declarations, commitments), and 2 are open design questions. Each den-hoag "discipline" is a reduce function or a plain query in sven ([hoag/ci.nix](modules/hoag/ci.nix)).

sini's fleet ([sini/nix-config](https://github.com/sini/nix-config)) gives 98 patterns ([vic/sini-patterns.md](https://github.com/vic/sven/blob/main/vic/sini-patterns.md)). Every one has a check, except packaging.

sven needs no strata, no effect runtime and no registry of merge algebras. The Nix lazy `let` is the only fixpoint for data; `sven.lib.datalog` gives the well-founded model when your rules need one. Structure can depend on presence at a parent, and two hosts can point at each other with no cycle error.

Three families of Den bugs cannot happen in sven:

- **Double delivery.** An element has one id per receiver.
- **Lost content when one aspect is in two files.** A read queries all files. Nothing merges early.
- **A host's home-manager content leaking to its users.** Elements go up the tree, never down.

## sven and clan

[clan](https://clan.lol) adds service instances, roles, exports and vars on top of NixOS. All its docs, its 31 services and its library give 79 capabilities ([vic/clan-patterns.txt](https://github.com/vic/sven/blob/main/vic/clan-patterns.txt)): 64 have a check here, 6 are clan internals, and 9 are tools (CLI, installers, secret generation). sven covers the configuration, not the tools.

| clan | sven | File |
|---|---|---|
| machines with tags (`all`, `nixos`, `darwin` are automatic) | host and mac instances with the field `labels` | [clan/inventory.nix](modules/clan/inventory.nix) |
| `inventory.instances.<i>`, `module.name` | the data kind `instance`; `module` defaults to the instance name | [clan/inventory.nix](modules/clan/inventory.nix) |
| role members: named machines and tagged machines | each machine spawns one `member` scope per (instance, role) | [clan/inventory.nix](modules/clan/inventory.nix) |
| `perInstance` | an aspect at a member scope | [clan/services.nix](modules/clan/services.nix) |
| `perMachine` | an aspect at a machine that `has` a member | [clan/services.nix](modules/clan/services.nix) |
| role settings, then machine settings, typed by the role interface | interface defaults, role, machine; a wrong type is an error record | [clan/inventory.nix](modules/clan/inventory.nix) |
| exports, `selectExports`, scope rules | a fleet sink; the engine sets the writer; a service lists its keys; the owner overrides from the fleet scope | [clan/inventory.nix](modules/clan/inventory.nix) |
| a service from another flake (`module.input`) | a module file imported as a function with args | [services/borg.nix](services/borg.nix) |
| vars generators, `share`, dependencies, `neededFor`, `deploy = false`, recipients | the `generators` sink and `out.varsPlan` | [clan/vars.nix](modules/clan/vars.nix) |
| autoincludes from `machines/<name>/` | a host per directory, its `configuration.nix` imported | [clan/vars.nix](modules/clan/vars.nix) |

## Shared pkgs: one nixpkgs per channel and system

sven's own part of a host is small: on lb it is 1.4% of the evaluation. Most of the time goes to nixpkgs `pkgs` (56%) and the NixOS module system (36%) ([vic/evalmodules-research.md](https://github.com/vic/sven/blob/main/vic/evalmodules-research.md)). By default each host imports nixpkgs again. A host with `sharedPkgs = true` reuses the `pkgs` of the first sharing host on its channel and system, through nixpkgs' `readOnlyPkgs` ([platforms/nixos.nix](modules/platforms/nixos.nix)).

The `lab` environment compares the two: `app-1`, `app-2` and `app-3` share, `app-4` builds its own ([hosts/apps.nix](modules/hosts/apps.nix)). `bench-shared.nix` evaluates app-1..3 both ways:

| app-1..3 toplevel | CPU | Thunks | Function calls |
|---|---|---|---|
| each its own pkgs | 19.0 s | 21.7 M | 17.0 M |
| shared pkgs | 12.7 s | 16.8 M | 12.9 M |

The prod hosts share too: `lb`, its variant `lb-minimal`, `web-1` and `web-2` join app-1's group (same channel and system). Evaluated both ways (`--arg hosts '[ "lb" "web-1" "web-2" ]'`):

| lb, web-1, web-2 toplevel | CPU | Thunks | Function calls | Values | Sets | Lists | GC total |
|---|---|---|---|---|---|---|---|
| each its own pkgs | 35.3 s | 36.6 M | 27.9 M | 806 MB | 929 MB | 76 MB | 2.71 GB |
| shared pkgs | 24.8 s | 29.3 M | 21.9 M | 641 MB | 585 MB | 61 MB | 1.96 GB |

The `drvPath`s are the same both ways. The e2e check `shared-pkgs-same-drv` proves it on every run, for all six followers: each follower's toplevel equals its build with its own `pkgs` (`nixosConfigurationsOwnPkgs`).

Two rules. A sharing host cannot set `nixpkgs.config` or `nixpkgs.overlays` of its own: its group shares them, so every host in the group must give the same. Here the overlays are fleet-wide, and the unfree and insecure permits are only on `stage`, which does not share. And documentation is off on every sharing host (`shared-pkgs-no-docs` in [platforms/nixos.nix](modules/platforms/nixos.nix)), because the manual and man pages differ when `pkgs` is shared. With docs on, the e2e check fails.

### A smaller NixOS module list

A host with `trimmedModules = true` evaluates only the NixOS base modules it needs: about 397 of 1,899 ([platforms/_modlists.nix](modules/platforms/_modlists.nix), computed in [vic/modlist-research.md](https://github.com/vic/sven/blob/main/vic/modlist-research.md) as the closure of a learned core and the options the host defines). The list filters `module-list.nix` itself, so the order and the inline entries stay. `web-1` and `app-2` use it:

| web-1, app-2 toplevel | CPU | Thunks | Function calls | Values | Sets | Lists | GC total |
|---|---|---|---|---|---|---|---|
| full list | 11.4 s | 14.57 M | 11.15 M | 323 MB | 327 MB | 31.1 MB | 1.03 GB |
| trimmed list | 10.5 s | 13.21 M | 10.15 M | 290 MB | 302 MB | 28.1 MB | 0.94 GB |

Three oracles hold it: the e2e check `modlist-same-drv` (each trimmed toplevel has the same `drvPath` as `nixosConfigurationsFull`), `modlist-negative` (the list without nginx fails for web-1, and the same list with nginx builds), and `bash cost.sh` (the drvPaths match and the trimmed eval uses at most 95% of the thunks). The lists belong to one nixpkgs revision: after an update, `modlist-same-drv` fails until they are computed again.

## Generated files and checks

`flake.nix`, `README.md` and `ci.json` are generated. Do not edit them. Edit `modules/`, then run:

```sh
nix run .#write-flake    # flake.nix from the `flake-file` sink (github:vic/flake-file)
nix run .#write-files    # README.md and ci.json (github:sini/files)
nix flake check          # fails if a generated file is stale
```

Each aspect declares the flake inputs it uses on the `flake-file` sink. The generated `flake.nix` has exactly those inputs.

`nix flake check` runs these checks on `x86_64-linux`:

| Check | What it proves |
|---|---|
| `flake-file` | `flake.nix` matches the inputs that the aspects declare |
| `files/README.md`, `files/ci.json` | the committed files match the fleet |
| `infra-<host>` | each fact that aspects state from fleet data holds in the built system: the hostname, nginx and port 80 where nginx is active, every persisted directory |
| `lb-no-gui` | lb's built system has no GUI package |
| `guard-pod` | an aspect applied alone to stand-in args (a cluster with the flag on) gives the expected manifest, whatever the fleet sets |
| `vmTests.x86_64-linux.web` (not a check) | a VM test: a client reaches nginx. It needs KVM, so CI does not run it; build it by hand |
| `pre-commit` | the hooks that aspects give |

The infra checks come from the fleet, not from a hand-written list. Add an aspect that states a fact, and every host where it is active gets the check.

`ci.json` is the CI matrix: one job for each host, mac, home and devshell. It is a generated file, so `files/ci.json` fails when the fleet changes and nobody regenerated the matrix.

## Tests

From this directory:

```sh
nix eval --impure --file tests.nix failed       # [ ]: a check for each pattern above
nix eval --impure --file tests.nix e2e.failed   # [ ]: real NixOS, darwin and home-manager evaluations
bash mcp/test.sh                                # PASS for each MCP case, the flake app included
```

From the sven repository root, the engine and library oracles, and the cost oracles. A memo is invisible to an eval, so `tests/cost.sh` bounds Nix's own counters (`NIX_SHOW_STATS`): 30 levels of aspect-ref diamonds and a 150-host fan-in must each stay under 200,000 function calls. Without the memos they take 26 million calls (at 16 levels) and 954,000.

```sh
nix-instantiate --eval --strict tests -A failed   # [ ]: engine, datalog, rdf, krn and shacl suites
bash tests/cost.sh                                # PASS aspect-ref-memo, PASS reduction-memo
```

GitHub Actions run all of these on each push and pull request ([.github/workflows/test.yml](https://github.com/vic/sven/blob/main/.github/workflows/test.yml)): the engine and cost oracles, the fleet checks and e2e evaluations, the fleet cost oracle, the MCP tests, `nix flake check` (with KVM for the VM test) and one job per `ci.json` target that must evaluate to a derivation.
