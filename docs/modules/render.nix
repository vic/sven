# The page aspect: each page gives its .mdx, its sidebar entry, its template and its tests.
# `docs` (yen.helpers.docs dir) writes Starlight markup: fences from the example's files, values from its queries, diagrams from its graph.
{ yen, lib, ... }:
let
  repo = "https://github.com/vic/yen";
  trim = lib.removeSuffix "\n";
  langOf =
    p:
    {
      nix = "nix";
      json = "json";
      sh = "sh";
      md = "md";
    }
    .${lib.last (lib.splitString "." p)} or "text";
  fence =
    lang: meta: text:
    "```${lang}${lib.optionalString (meta != "") " ${meta}"}\n${trim text}\n```";
  indent =
    n: text:
    lib.concatStringsSep "\n" (
      lib.imap0 (i: l: if i == 0 || l == "" then l else lib.fixedWidthString n " " "" + l) (
        lib.splitString "\n" text
      )
    ); # continuation lines only
  attr = v: lib.replaceStrings [ "\"" ] [ "&quot;" ] v;
  # every file of a template, as Starlight's FileTree list
  treeOf =
    dir: pre:
    lib.concatLists (
      lib.mapAttrsToList (
        n: t:
        if t == "directory" then
          [ "${pre}- ${n}/" ] ++ treeOf (dir + "/${n}") "${pre}  "
        else
          [ "${pre}- ${n}" ]
      ) (lib.filterAttrs (n: _: n != "page.nix") (builtins.readDir dir))
    );

  docs = dir: rec {
    # a file of the example, as a titled code block. `meta` adds expressive-code marks: "{2-3}", "ins={4}"
    fileWith =
      meta: p:
      fence (langOf p) (lib.concatStringsSep " " (
        lib.filter (x: x != "") [
          ''title="${p}"''
          meta
        ]
      )) (builtins.readFile (dir + "/${p}"));
    file = fileWith "";
    code = lang: text: fence lang "" text;
    nix = code "nix";
    sh = text: fence "sh" ''frame="terminal"'' text;
    # a Nix value, printed: what a query answers
    value =
      v:
      fence "nix" ''title="result"'' (
        builtins.replaceStrings [ "${toString dir}/" ] [ "" ] (lib.generators.toPretty { } v)
      ); # paths relative to the template
    aside =
      type: title: body:
      ":::${type}[${title}]\n${trim body}\n:::";
    note = aside "note";
    tip = aside "tip";
    caution = aside "caution";
    tabs =
      items:
      lib.concatStringsSep "\n" (
        [ "<Tabs>" ]
        ++ map (i: "<TabItem label=\"${attr i.label}\">\n\n${trim i.body}\n\n</TabItem>") items
        ++ [ "</Tabs>" ]
      );
    steps =
      items:
      "<Steps>\n\n${
        lib.concatStringsSep "\n\n" (lib.imap1 (i: s: "${toString i}. ${indent 3 (trim s)}") items)
      }\n\n</Steps>";
    cards =
      items:
      "<CardGrid>\n${
        lib.concatMapStringsSep "\n" (
          c: "<Card title=\"${attr c.title}\" icon=\"${c.icon or "star"}\">\n\n${trim c.body}\n\n</Card>"
        ) items
      }\n</CardGrid>";
    links =
      items:
      "<CardGrid>\n${
        lib.concatMapStringsSep "\n" (
          c:
          "<LinkCard title=\"${attr c.title}\" href=\"${c.href}\" description=\"${attr (c.description or "")}\" />"
        ) items
      }\n</CardGrid>";
    badge = text: variant: "<Badge text=\"${attr text}\" variant=\"${variant}\" />";
    table =
      head: rows:
      lib.concatStringsSep "\n" (
        [
          "| ${lib.concatStringsSep " | " head} |"
          "|${lib.concatMapStrings (_: "---|") head}"
        ]
        ++ map (r: "| ${lib.concatStringsSep " | " r} |") rows
      );
    tree = "<FileTree>\n\n${lib.concatStringsSep "\n" (treeOf dir "")}\n\n</FileTree>";
    mermaid = text: fence "mermaid" "" text;
    # the scope tree of an eval result: each scope under its parent
    scopes =
      r:
      mermaid (
        yen.lib.batteries.mermaid.flowchart { direction = "TD"; } (
          yen.lib.batteries.mermaid.scopes { } r.graph
        )
      );
    # routed elements: who gives what to whom (an element given at its own scope is a loop, left out)
    routes =
      r:
      mermaid (
        yen.lib.batteries.mermaid.flowchart { direction = "BT"; } (yen.lib.batteries.mermaid.routes r.graph)
      );
    fleet =
      path: line: label:
      "[${label}](${repo}/blob/main/templates/fleet/${path}${
        lib.optionalString (line != null) "#L${toString line}"
      })";
    src = p: "${repo}/blob/main/docs/examples/${baseNameOf dir}/${p}";
  };

  imports = "import { Aside, Badge, Card, CardGrid, FileTree, LinkButton, LinkCard, Steps, TabItem, Tabs } from '@astrojs/starlight/components';";
  frontmatter =
    page: p: d:
    "---\n${
      builtins.toJSON (
        {
          inherit (page) title description;
          editUrl = d.src "page.nix";
        }
        // (p.frontmatter or { })
      )
    }\n---";
  runIt =
    page: d:
    d.tip "Run this example" ''
      Every block on this page is a file of the template `${page.name}`. Copy it and run it:

      ${d.sh "nix flake init -t github:vic/yen#${page.name}"}

      ${d.tree}
    '';
  # every page as data, in site order: for landing pages and indexes. Tree requests give the instances with their data.
  allPages.instances = yen.kinds.page; # a tree request: every page, with its data
  allSections.instances = yen.kinds.section; # a tree request: every section, with its data
  pagesOf =
    instances:
    map
      (p: {
        inherit (p)
          name
          title
          description
          route
          order
          ;
        section = p.section.name;
      })
      (
        lib.sort (
          a: b:
          if a.section.order == b.section.order then a.order < b.order else a.section.order < b.section.order
        ) instances
      );
  bodyOf =
    commands: pages: page:
    let
      x = yen.helpers.example page.dir;
    in
    x.page.body {
      docs = docs page.dir;
      inherit (x)
        result
        flake
        variant
        only
        dir
        inputs
        module
        engine
        ;
      inherit lib pages commands;
    };
  render =
    commands: pages: page:
    let
      x = yen.helpers.example page.dir;
      d = docs page.dir;
    in
    lib.concatStringsSep "\n\n" (
      [
        (frontmatter page x.page d)
        imports
      ]
      ++ bodyOf commands pages page
      ++ lib.optional x.template (runIt page d)
    )
    + "\n";
  # a page can also be a plain markdown repo file (CONTRIBUTING.md): its body only, so it must not use MDX components
  plain =
    commands: pages: page:
    lib.concatStringsSep "\n\n" (
      [
        "# ${(yen.helpers.example page.dir).page.plainTitle or page.title}"
        "<!-- Generated from docs/examples/${page.name}/page.nix. Edit there, then run `nix run .#write-files` in docs/. -->"
      ]
      ++ bodyOf commands pages page
    )
    + "\n";
  # a fastest test: { expr; expected; }
  eq = expr: expected: { inherit expr expected; };
  yes = x: eq x true;
  no = x: eq x false;
  testsOf =
    commands: pages: page:
    let
      x = yen.helpers.example page.dir;
      args = {
        inherit (x)
          result
          flake
          variant
          only
          dir
          inputs
          module
          engine
          ;
        inherit
          lib
          pages
          commands
          eq
          yes
          no
          ;
      };
      own = (x.page.checks or (_: { })) args;
      auto =
        lib.optionalAttrs (x.result != null) {
          no-errors = if x.page.errors or false then yes true else eq (map (e: e.error) x.result.errors) [ ];
        }
        // lib.optionalAttrs x.template {
          inputs-known = yes x.inputsKnown;
          flake-is-eval = eq (lib.attrNames x.flake) (lib.attrNames x.result.flake);
        };
    in
    {
      fast = auto // own;
      e2e = (x.page.e2e or (_: { })) args;
    };
in
{
  yen.helpers.docs = docs;
  # a page renders the other pages (its lists, its links), so it is a cycle: a tree request gives every page with its data
  yen.aspects.page = {
    at = yen.kinds.page;
    cycle =
      {
        scope,
        tree,
        commands,
        ...
      }:
      let
        page = scope;
        pages = pagesOf (lib.head (tree.select allPages));
        cmds = lib.concatLists (lib.head commands); # the reduced `commands` sink: each aspect gives a list
      in
      {
        tree = [ allPages ];
        files = [
          {
            files.file = {
              "src/content/docs/${page.route}.mdx".text = render cmds pages page;
            }
            // lib.optionalAttrs ((yen.helpers.example page.dir).page ? alsoAt) {
              ${(yen.helpers.example page.dir).page.alsoAt}.text = plain cmds pages page;
            };
          }
        ];
        sidebar = [
          {
            section = page.section;
            inherit (page) order;
            item = {
              label = page.title;
              slug = page.route;
            }
            // lib.optionalAttrs (page.badge != null) { badge = page.badge; };
          }
        ];
        tests = [
          {
            ${page.name} = testsOf cmds pages page;
          }
        ];
      };
  };
  # every internal link of every page resolves to a page: `/route/` or `/route/#anchor`
  yen.aspects.links = {
    at = yen.kinds.site;
    cycle =
      { tree, commands, ... }:
      let
        instances = lib.head (tree.select allPages);
        pages = pagesOf instances;
        cmds = lib.concatLists (lib.head commands);
        routes = map (p: if p.route == "index" then "/" else "/${p.route}/") pages;
        linksIn =
          t:
          lib.concatMap (x: if lib.isList x then x else [ ]) (builtins.split ''([]][(]|href=")(/[^)"#]*)'' t);
        found = lib.unique (
          lib.filter (l: lib.hasPrefix "/" l) (lib.concatMap (p: linksIn (render cmds pages p)) instances)
        );
        broken = lib.filter (l: !lib.elem l routes && !lib.hasPrefix "/yen.png" l) found;
      in
      {
        tree = [ allPages ];
        tests = [
          {
            site = {
              fast = {
                links-resolve = eq broken [ ];
              };
              e2e = { };
              inherit broken;
            };
          }
        ];
      };
  };
  # the sidebar: sections in order, pages in order; the home page (path "index") is the splash, not in the sidebar
  yen.aspects.sidebar = {
    at = yen.kinds.site;
    cycle =
      { sidebar, tree, ... }:
      let
        shown = lib.filter (e: e.item.slug != "index") (lib.head sidebar);
        bySection = lib.groupBy (e: e.section.name) shown;
        sections = lib.sort (a: b: a.order < b.order) (
          lib.filter (s: bySection ? ${s.name}) (lib.head (tree.select allSections))
        );
      in
      {
        tree = [ allSections ];
        files = [
          {
            files.file."src/sidebar.json".text =
              builtins.toJSON (
                map (s: {
                  label = s.title;
                  items = map (e: e.item) (lib.sort (a: b: a.order < b.order) bySection.${s.name});
                }) sections
              )
              + "\n";
          }
        ];
      };
  };
}
