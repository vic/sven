# shared by the clan batteries: which machines take a role (by name or by tag), and clan's settings layers
let
  b = builtins;
  merge =
    a: c:
    a // b.mapAttrs (k: v: if b.isAttrs v && b.isAttrs (a.${k} or null) then merge a.${k} v else v) c;
in
{
  # a machine takes a role when the role names it, or names one of its tags
  roleHas =
    labelsOf: r: m:
    (r.machines or { }) ? ${m.name} || b.any (t: b.elem t (labelsOf m)) (r.tags or [ ]);
  # interface defaults, then role-wide settings, then this machine's (clan finalSettings)
  settingsOf =
    services: i: r: m:
    let
      iface = services.${i.module}.roles.${r}.interface or { };
      role = i.roles.${r};
    in
    b.foldl' merge (b.mapAttrs (_: o: o.default or null) iface) [
      (role.settings or { })
      (role.machines.${m.name}.settings or { })
    ];
}
