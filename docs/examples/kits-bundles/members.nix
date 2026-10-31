# the members of each machine as `assembly.role` names, and the exports as `kit:assembly:role:machine`
result: {
  of =
    m:
    builtins.sort (a: b: a < b) (
      map (s: s.name) (builtins.filter (s: s.kind == "member" && s.parent.name == m) result.scopes)
    );
  exports = map (e: "${e.kit.name}:${e.assembly.name}:${e.role}:${e.machine.name}") (
    result.reduced.exports."fleet:main" or [ ]
  );
}
