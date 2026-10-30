# Shared values. `yen.helpers` is a query like any other declaration.
{
  yen,
  lib,
  inputs,
  ...
}:
let
  inherit (yen.lib) same holds;
in
{
  yen.helpers = {
    machines = [
      yen.kinds.host
      yen.kinds.guest
      yen.kinds.mac
    ];
    linux = [
      yen.kinds.host
      yen.kinds.guest
    ];
    listOf = yen.lib.listOf; # a list of refs stays a ref field
    enum = xs: yen.lib.is (v: lib.elem v xs);
    pkgsOf = m: m.channel.nixpkgs.legacyPackages.${m.system.name};
    inEnv = xs: s: lib.filterAttrs (_: x: same x.environment s) xs;
    upTo = p: s: lib.findFirst (holds p) null (lib.reverseList s.up); # nearest ancestor-or-self where p holds
    # nested groups: every group that contains one of gs, transitively
    closure =
      groups: gs:
      map (x: x.g) (
        builtins.genericClosure {
          startSet = map (g: {
            key = g.name;
            inherit g;
          }) gs;
          operator =
            x:
            map (p: {
              key = p.name;
              g = p;
            }) (lib.filter (p: lib.any (same x.g) p.members) groups);
        }
      );
    # ACL: a posix group of the user meets the environment's or the machine's grants, and the machine's gates when it has any
    meets = xs: ys: lib.any (x: lib.any (same x) ys) xs;
    posixOf =
      u: lib.filter (g: g.label == "posix") (yen.helpers.closure (lib.attrValues yen.group) u.groups);
    usersOn =
      s:
      lib.filterAttrs (
        _: u:
        let
          gs = yen.helpers.posixOf u;
        in
        yen.helpers.meets gs (s.environment.grants ++ s.grants)
        && (s.gates == [ ] || yen.helpers.meets gs s.gates)
      ) yen.user;
    flatten = a: ms: lib.mkMerge (map (m: if lib.isFunction m then m a else m) ms); # config-only submodules (users.users.<n>)
    noGui =
      system: h: cfg: bad:
      let
        hit = lib.intersectLists bad (map lib.getName cfg.config.environment.systemPackages);
      in
      inputs.nixpkgs.legacyPackages.${system.name}.runCommand "${h}-no-gui" { } (
        if hit == [ ] then "touch $out" else "echo 'gui on ${h}: ${toString hit}'; exit 1"
      );
    mermaid =
      g: yen.lib.batteries.mermaid.flowchart { direction = "TD"; } (yen.lib.batteries.mermaid.routes g);
    ids =
      fleet:
      lib.listToAttrs (
        lib.imap0 (i: n: lib.nameValuePair n i) (
          lib.sort (a: b: a < b) (
            map (s: s.name) (lib.filter (s: fleet.lib.holds fleet.kinds.host s) fleet.lib.graph.scopes)
          )
        )
      ); # deterministic: sorted host scope names
  };
}
