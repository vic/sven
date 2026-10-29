{
  title = "yen";
  description = "Nix configurations you can ask questions about, and prove things about, before you deploy.";
  section = "start";
  order = 0;
  route = "index";
  frontmatter = {
    template = "splash";
    hero = {
      tagline = "Nix configurations you can ask questions about,\nand prove things about, before you deploy.";
      image.html = ''<img src="/yen.png" style="max-width: 80%" />'';
      actions = [
        {
          text = "Overview";
          link = "/start/overview/";
          icon = "nix";
        }
        {
          text = "Getting started";
          link = "/start/getting-started/";
          icon = "rocket";
          variant = "minimal";
        }
        {
          text = "Recipes";
          link = "/recipes/";
          icon = "puzzle";
          variant = "minimal";
        }
        {
          text = "Source code";
          link = "https://github.com/vic/yen";
          icon = "github";
          variant = "minimal";
        }
      ];
    };
  };

  body =
    { docs, ... }:
    [
      ''
        **yen is a query language for Nix configurations.** You write plain Nix data and behavior.
        yen answers queries on it: the NixOS, nix-darwin and home-manager systems to build, the errors,
        the graph of who gives what to whom, and whether your rules hold.
      ''
      (docs.cards [
        {
          title = "Data is queried, not merged";
          icon = "magnifier";
          body = "Kinds, instances and typed fields are data. Content in many files never overwrites itself.";
        }
        {
          title = "Behavior lands where you say";
          icon = "puzzle";
          body = "An aspect is active where its predicate holds. Its elements go to the nearest scope that collects them.";
        }
        {
          title = "Questions have answers";
          icon = "approve-check";
          body = "Graphs, Datalog with a well-founded semantics, and µKanren with constraints. All pure Nix.";
        }
        {
          title = "Safe for agents";
          icon = "warning";
          body = "A change is staged, checked against your rules across machines, and refused with its reason. An MCP server answers agents.";
        }
      ])
      ''
        ---
      ''
      (docs.note "Every page is a tested example" ''
        Each code block in these docs is a file of a flake template. The docs flake evaluates every template and
        checks its answers, then writes these pages with [sini/files](https://github.com/sini/files).
        A page cannot show code that does not run.
      '')
    ];
}
