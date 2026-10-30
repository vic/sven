# a view of every scope of `yen.lib.graph`, under its parent
let
  b = builtins;
  parentOf =
    id:
    let
      parts = b.filter b.isString (b.split "/" id);
    in
    b.concatStringsSep "/" (b.genList (b.elemAt parts) (b.length parts - 1));
  isUnder = s: b.match ".*/.*" s.id != null;
in
g: {
  nodes = map (s: {
    inherit (s) id kind;
    label = "${s.kind} ${s.name}";
  }) g.scopes;
  edges = map (s: {
    from = parentOf s.id;
    to = s.id;
  }) (b.filter isUnder g.scopes);
}
