let
  site = "https://yen.oeiuwq.com";
  link = text: path: "[${text}](${site}${path})"; # absolute: this page is also the repository README
in
{
  title = "Why Yen";
  plainTitle = "Yen: catch the broken fleet before you build it";
  description = "Formal methods, made for agents, on reproducible infrastructure: fleets of hundreds of services, checked before build and deploy.";
  section = "start";
  order = 0;
  alsoAt = "../README.md"; # the same text is the repository README: plain markdown only

  body =
    { ... }:
    [
      ''
        **Your infrastructure builds. Is it correct?**

        Nix made builds reproducible. It did not make fleets correct. Every machine can evaluate, build and boot,
        and the fleet is still wrong: a lab service that talks to the prod database, a client with no server,
        two services that claim the same thing. No single machine sees it. You find it in production.

        Now agents write your infrastructure changes, faster than anyone can review them.
        Reading diffs does not scale to hundreds of services. Rules do.

        **Yen brings formal methods, made for agents, to reproducible infrastructure at scale.**
        Our mission: fleets of hundreds of services, reproducible and verified, where a broken rule stops a change
        before you build it and before you deploy it.

        ${link "Documentation" "/"} · ${link "A fleet on one page" "/start/one-page-fleet/"} · [Reference fleet](https://github.com/vic/yen/tree/main/templates/fleet) · [Sponsor vic](https://dendritic.oeiuwq.com/sponsor)

        ## What you get today

        - **Rules across machines.** Write your invariants once, as logic over your fleet. Yen checks them on every
          evaluation. A rule that cannot be decided is a failure, never a pass.
        - **Nothing to build from a broken fleet.** An error or a broken rule and Yen gives no outputs, and no values
          to build them from by hand.
        - **Agents that cannot break the law.** An agent's change is staged: Yen evaluates the fleet with and without it,
          applies nothing, and refuses it with the rule it breaks. A change can never touch your rules, and a grant
          keeps it in its lane: anything it could reach outside the grant is refused.
        - **Answers, not stack traces.** Every answer is plain data an agent can read: errors with fixes, why a rule fires,
          why it does not. Agents ask through queries or an MCP server.
        - **Your words, not ours.** Yen does not know what a host or a service is. You name your own nouns and facts.
          NixOS, nix-darwin, home-manager, clusters: if you can write it as Nix values, Yen can check it.
        - **Just Nix.** A few files of Nix builtins. No dependencies.

        ## Where we are going

        Yen is young, and we say plainly what is not done yet. Each step lands with its own tests:

        - **Precise grants.** Today a grant is coarse: a change that declares anything is refused everywhere outside it.
          Next, Yen sees every read, so a grant refuses only what the change really reaches.
        - **Typed facts and rules as data.** Facts that cannot collide, and rules Yen can inspect.
        - **Certificates.** Each verdict ships with evidence that a small, trusted checker re-verifies.
        - **Types as proofs.** A typed value carries the proof of its own check.
        - **Proven at scale.** Measured checks on fleets of hundreds of services.

        ## Try it

        Read ${link "A fleet on one page" "/start/one-page-fleet/"}: three hosts, a rule across machines,
        and an agent's change that Yen refuses. Then the ${link "documentation" "/"}: every page is a tested example.

        Yen is made by [vic](https://github.com/vic), with love, as part of the [Dendritic ecosystem](https://dendritic.oeiuwq.com).
        If Yen helps you, please [sponsor vic](https://dendritic.oeiuwq.com/sponsor). Issues and pull requests are welcome:
        see [CONTRIBUTING.md](CONTRIBUTING.md).
      ''
    ];
}
