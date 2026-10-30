let
  site = "https://yen.oeiuwq.com";
  link = text: path: "[${text}](${site}${path})"; # absolute: this page is also the repository README
in
{
  title = "Why Yen";
  plainTitle = "Yen: formal methods for reproducible Nix fleets";
  description = "Rules across machines, proved before build and deploy: fleets of hundreds of services, safe for people and agents.";
  section = "start";
  order = 0;
  alsoAt = "../README.md"; # the same text is the repository README: plain markdown only

  body =
    { ... }:
    [
      ''
        **Nix makes every build reproducible. Yen makes the whole fleet provable.**

        A fleet can evaluate, build and boot on every machine and still be wrong: a lab service that writes to the prod
        database, a client with no server, two services on one port. No single machine sees these mistakes, because they
        live between machines. Yen checks them before anything is built or deployed, with rules you write about your
        own fleet, and it proves each answer.

        Agents now write infrastructure changes faster than anyone can review them. Yen lets them work safely: a change
        is staged, checked against your rules, and refused with the reason, before it reaches a machine.

        ${link "Documentation" "/"} · ${link "A fleet on one page" "/start/one-page-fleet/"} · [Reference fleet](https://github.com/vic/yen/tree/main/templates/fleet) · [Sponsor vic](https://dendritic.oeiuwq.com/sponsor)

        ## A rule across machines

        Your fleet becomes facts: `[ "ref" "db" HOST "host" NAME ]`, `[ "has" ASPECT SCOPE ]`, `[ "val" FIELD SCOPE VALUE ]`.
        A rule is data. This one says a host's database lives in its own environment:

        ```nix
        yen.invariants.db-same-env = [{
          head = [ "bad" "db-other-env" (v "H") ];
          pos = [
            [ "ref" "db" (v "H") "host" (v "N") ]       # H uses the host named N as its database
            [ "instance" (v "D") "host" (v "N") ]      # D is that host
            [ "ref" "env" (v "H") "env" (v "E") ]      # H lives in environment E
          ];
          neg = [ [ "ref" "env" (v "D") "env" (v "E") ] ];  # and D does not
        }];
        ```

        A lab host that points at the prod database gives `[ "bad" "db-other-env" "fleet:main/env:lab/host:api" ]`,
        and the fleet gives no outputs at all.

        ## What Yen gives you

        - **Rules as data, over typed facts.** Datalog with variables and negation, under the well-founded semantics.
          A rule that cannot be decided is a failure, never a pass. Relations are declared, and a rule can never forge a fact.
        - **Proofs with every verdict.** Each verdict carries a staged certificate (Van Gelder, Ross and Schlipf, 1991)
          that a small checker in plain Nix verifies. A seal binds the verdict to the hashes of the engine, the rules and
          the facts, so anyone can check it again.
        - **Nothing to build from a broken fleet.** An error, a violation or an undecided rule and Yen gives no outputs,
          and no values to build them from.
        - **Safe changes from agents.** A change is evaluated with and without it, and nothing is applied. It is refused
          with the rule it breaks, it can never change the rules, and a grant limits where it may reach. Each change
          carries its author's trust label.
        - **Types in rules.** Any type, or any total function, is a predicate a rule can use.
        - **Secrets stay secret.** A secret field is stated only by its hash in every answer; rules still compare secrets.
        - **Answers for agents.** Errors with fixes, why a rule holds or does not, where each fact comes from: all plain
          data. A Rust MCP server serves them, and a skill teaches agents to use it.
        - **Built for hundreds of services.** 1600 services under rules across machines, checked and certified in seconds.
        - **Your words, not ours.** Yen has no vocabulary: you name your own kinds and facts. NixOS, nix-darwin,
          home-manager, clusters: anything you write as Nix values.
        - **Just Nix.** A few files of Nix builtins, no dependencies. Every page of the docs is a tested example.

        ## Sponsor this work

        Formal methods for reproducible infrastructure is new ground, and Yen is built in the open, with every
        capability tested. If your fleet, your team or your agents would gain from it, please
        [sponsor vic](https://dendritic.oeiuwq.com/sponsor). Sponsorship keeps this work going.

        ## Try it

        Read ${link "A fleet on one page" "/start/one-page-fleet/"}: three hosts, a rule across machines, and an agent's
        change that Yen refuses. Then the ${link "documentation" "/"}.

        Yen is made by [vic](https://github.com/vic), with love, as part of the [Dendritic ecosystem](https://dendritic.oeiuwq.com).
        Issues and pull requests are welcome: see [CONTRIBUTING.md](CONTRIBUTING.md).
      ''
    ];
}
