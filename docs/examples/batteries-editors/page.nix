{
  title = "Editor and AI batteries";
  description = "VS Code and Zed from language aspects; one pool of agent extensions (skills, MCP servers) that each agent filters.";
  section = "batteries";
  route = "batteries/editors";
  order = 9;

  body =
    { docs, ... }:
    [
      ''
        An editor's extension list grows with every language you use, and every AI agent wants the same skills and MCP
        servers in its own format. With these batteries a language aspect or a tool aspect gives what it needs once;
        each editor and each agent reads the pool.

        | Battery | Value of | Gives |
        |---|---|---|
        | `editors.vscode { from; profile; }` | a home-manager key of a sink of `{ extensions; settings; }` | `programs.vscode` |
        | `editors.zed { from; }` | the same, extensions by name | `programs.zed-editor` |
        | `ai.extensions { from; types; build; }` | any key | `build` of the records of the given types (an element may be a list) |
        | `ai.skills dir` | an element | one `{ type = "skill"; name; path; }` per subdirectory with a SKILL.md |
      ''
      (docs.file "modules/fleet.nix")
      (docs.file "modules/languages.nix")
      (docs.file "skills/review/SKILL.md")
    ];

  checks =
    {
      result,
      eq,
      yes,
      no,
      ...
    }:
    {
      homes = eq (builtins.attrNames result.flake.homeConfigurations) ([ "ana" ]);
    };

  e2e =
    {
      flake,
      eq,
      yes,
      no,
      ...
    }:
    let
      c = flake.homeConfigurations.ana.config;
      vs = c.programs.vscode.profiles.default;
    in
    {
      vscode = {
        t1 = yes (c.programs.vscode.enable);
        t2 = yes (map (e: e.pname or e.name) vs.extensions != [ ]);
        t3 = eq (builtins.length vs.extensions) (2);
        t4 = yes (vs.userSettings."nix.enableLanguageServer");
      };
      zed = eq (builtins.sort builtins.lessThan c.programs.zed-editor.extensions) ([
        "go"
        "nix"
      ]);
      skills = {
        t1 = yes (c.home.file ? ".claude/skills/review");
        t2 = no ((c.home.file ? ".claude/skills/notes")); # no SKILL.md: not a skill
        t3 = no ((c.home.file ? ".claude/skills/github")); # an mcp record: the skills agent skips it
      };
    };
}
