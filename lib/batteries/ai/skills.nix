#: lib.batteries.ai.skills :: dir -> [ { type; name; path; } ] -- one skill record per subdirectory with a SKILL.md
# skills from a directory: one record `{ type = "skill"; name; path; }` per subdirectory that has a SKILL.md, for an
# extensions pool.
#   agent-ext = ai.skills ./skills;
dir:
let
  b = builtins;
  ds = b.readDir dir;
in
map (n: {
  type = "skill";
  name = n;
  path = dir + "/${n}";
}) (b.filter (n: ds.${n} == "directory" && b.pathExists (dir + "/${n}/SKILL.md")) (b.attrNames ds))
