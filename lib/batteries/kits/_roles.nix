# shared by the kits batteries: a machine takes a role when the role's `at` holds there; the settings layers
let
  b = builtins;
  merge =
    a: c:
    a // b.mapAttrs (k: v: if b.isAttrs v && b.isAttrs (a.${k} or null) then merge a.${k} v else v) c;
in
{
  takes =
    holds: r: m:
    holds (r.at or [ ]) m;
  # interface defaults, then the role's settings: attrs, or a function of the machine
  settingsOf =
    a: r: m:
    let
      s = a.roles.${r}.settings or { };
    in
    merge (b.mapAttrs (_: o: o.default or null) (a.kit.roles.${r}.interface or { })) (
      if b.isFunction s then s m else s
    );
}
