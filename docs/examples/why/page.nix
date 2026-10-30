let
  site = "https://yen.oeiuwq.com";
  link = text: path: "[${text}](${site}${path})"; # absolute: this page is also the repository README
  doc = path: "<sub>[docs](${site}${path})</sub>"; # a small link after a point, so the prose stays clean
in
{
  title = "Why Yen";
  plainTitle = "Yen: your whole Nix fleet, in plain data";
  description = "Every Den capability and more, with a minimal language and less evaluation; rules across machines checked before you deploy.";
  section = "start";
  order = 0;
  alsoAt = "../README.md"; # the same text is the repository README: plain markdown only

  body =
    { ... }:
    [
      ''
        **Your homelab, your laptops, your servers: one fleet, described as plain data.**

        Yen configures NixOS, nix-darwin and home-manager machines from a few files you can read. Say what you have
        (hosts, users, environments) and what each feature needs, and Yen puts every piece of configuration where it
        belongs. It does everything [Den](https://github.com/denful/den) does, and more, with less to learn and less to
        evaluate.

        ${link "Documentation" "/"} · ${link "Getting started" "/start/getting-started/"} · ${link "A fleet on one page" "/start/one-page-fleet/"} · [Reference fleet](https://github.com/vic/yen/tree/main/templates/fleet) · [Sponsor vic](https://dendritic.oeiuwq.com/sponsor)

        ## A fleet is data

        ```nix
        yen.env.prod.domain = "example.com";
        yen.env.lab.domain = "lab.example.com";
        yen.host.web = { env = yen.env.prod; db = yen.host.db; };
        yen.host.db.env = yen.env.prod;
        yen.host.box.env = yen.env.lab;
        yen.user.ana.on = [ yen.host.web yen.host.box ];   # ana gets an account on both

        yen.aspects.postgres = {
          at = s: lib.any (h: same h.db s) (lib.attrValues yen.host);   # wherever some host uses me as its database
          os.services.postgresql.enable = true;
        };
        ```

        No host file lists its features: the data decides. Add a host and it gets everything it should.

        ## A rule across machines

        Some mistakes live between machines: no single host can see them. Say once that a host's database lives in its own
        environment:

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

        A lab host that points at the prod database gives `[ "bad" "db-other-env" "fleet:main/env:lab/host:api" ]`, and
        the fleet builds nothing until it is fixed.

        ## Why Yen

        - **Minimal language.** A handful of ideas: the things in your world, a tree built from your data, features that
          apply where a condition holds, and a place for each piece of configuration to go. ${doc "/start/overview/"}
        - **Domain agnostic.** Anything Nix can configure: NixOS, nix-darwin, home-manager, clusters and more. Name the
          things in your world: hosts, users, services, or your own.
        - **Everything Den does, and more.** Hosts, users, homes, includes, defaults, batteries, guests, roles, secrets,
          generated files. Migration guides build the same systems before and after, from `configuration.nix`, a flake or
          Den. ${doc "/migrate/from-den/"}
        - **Queried, not merged.** Each value is a query on the files that declare it. Content in many files never
          overwrites itself, and two different answers are an error you can read. ${doc "/concepts/queried-not-merged/"}
        - **Less to evaluate.** Yen itself is about 1% of a host's evaluation. One nixpkgs per system instead of one per
          host saves about a third, with a check that proves every system is the same. ${doc "/perf/shared-pkgs/"}
        - **Mistakes are caught early, with a fix.** A typo gets a "did you mean". Every error says where it is, what was
          expected and how to fix it. ${doc "/concepts/errors/"}
        - **Ask your fleet anything.** Graphs for deploy waves, cycles and impact; Datalog with negation; stored queries
          you name once and ask from Nix, the CLI or an agent. ${doc "/query/queries/"}
        - **Values that solve themselves.** µKanren with finite domains, in pure Nix: a free port, guest memory that fits,
          relations that run backward. ${doc "/query/krn/"}
        - **Rules across machines.** Write a rule once, and a fleet that breaks it builds nothing. Each verdict comes with
          a proof that a small checker verifies, and a seal anyone can check again. ${doc "/query/invariants/"}
        - **Time and impact.** What a host's elements reach, the fleet without one declaration, instances valid at a
          date. ${doc "/agents/history/"}
        - **Ready for agents.** An AI agent can ask about your fleet, stage a change and see why it is refused, before
          anything is applied. Yen ships an MCP server and a skill that teaches agents to use it. ${doc "/agents/mcp/"}
        - **Just Nix.** A few files of Nix builtins, no dependencies. Every page of the docs is a tested example.

        ## Try it

        ```sh
        nix flake init -t github:vic/yen#one-page-fleet
        ```

        Then read ${link "A fleet on one page" "/start/one-page-fleet/"} and the ${link "documentation" "/"}.

        ## Sponsor

        Yen is made by [vic](https://github.com/vic), with love, as part of the [Dendritic ecosystem](https://dendritic.oeiuwq.com).
        It brings formal verification to reproducible Nix fleets: your rules across machines, decided and proved before
        you deploy, so that big fleets stay correct as they grow. If Yen helps
        your homelab, your team or your agents, please [sponsor vic](https://dendritic.oeiuwq.com/sponsor).
        Issues and pull requests are welcome: see [CONTRIBUTING.md](CONTRIBUTING.md).
      ''
    ];
}
