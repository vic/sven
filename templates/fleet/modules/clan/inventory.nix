# clan's inventory in yen: a service instance is data. Each machine spawns one `member` scope per (instance, role)
# it takes part in, so an aspect at a member scope runs once per instance (clan perInstance) and an aspect at the
# machine that `has` a member runs once per machine (clan perMachine). Members read every instance as data.
# Exports are a fleet sink: the engine sets `from` (the member scope), so a service cannot write another's scope.
{ yen, lib, ... }:
let
  inherit (yen.lib) opt;
  attrs = yen.lib.is lib.isAttrs;
  # clan's automatic tags: all, and the machine class
  labelsOf =
    m:
    [
      "all"
      (if yen.lib.holds yen.kinds.mac m then "darwin" else "nixos")
    ]
    ++ m.labels;
  roleHas =
    r: m: (r.machines or { }) ? ${m.name} || lib.any (t: lib.elem t (labelsOf m)) (r.tags or [ ]);
  service = i: yen.helpers.clan.services.${i.module} or null;
  # settings: interface defaults, then role-wide, then this machine's (clan finalSettings)
  settingsOf =
    i: r: m:
    let
      iface = (service i).roles.${r}.interface or { };
      role = i.roles.${r};
    in
    lib.foldl' lib.recursiveUpdate (lib.mapAttrs (_: o: o.default or null) iface) [
      (role.settings or { })
      (role.machines.${m.name}.settings or { })
    ];
  all = yen.helpers.clan.instances;
in
{
  yen.kinds.machine.fields.labels = opt (yen.helpers.listOf lib.types.str) [ ];
  yen.kinds.instance.fields = {
    module = yen.lib.derive lib.types.str (self: self.name);
    roles = opt attrs { };
  };
  yen.helpers.clan = {
    services = { };
    # instances as data, plus the instances services add (clan nested services)
    instances = yen.instance // lib.concatMapAttrs (_: i: (service i).adds or (_: { }) i) yen.instance;
    selectExports = q: lib.filter (e: lib.all (k: e.${k} == q.${k}) (lib.attrNames q));
  };
  yen.kinds.member = { }; # spawned under machines; its elements go up to the machine
  yen.kinds.host.spawns.member = s: yen.helpers.clan.membersOf s;
  yen.kinds.mac.spawns.member = s: yen.helpers.clan.membersOf s;
  yen.helpers.clan.membersOf =
    m:
    lib.listToAttrs (
      lib.concatLists (
        lib.mapAttrsToList (
          n: i:
          lib.concatMap (
            r:
            lib.optional (roleHas i.roles.${r} m) (
              lib.nameValuePair "${n}.${r}" {
                instance = n;
                service = i.module;
                role = r;
                settings = settingsOf i r m;
                extraModules = i.roles.${r}.extraModules or [ ];
              }
            )
          ) (lib.attrNames i.roles)
        ) all
      )
    );

  # one fleet sink for exports; a reader filters by service, instance, role and machine (clan selectExports).
  # A member writes only under its own scope. An element from the fleet scope is the owner's override of one entry.
  # A service lists the export keys it may give (clan manifest.exports.out).
  yen.kinds.fleet.sinks.exports.reduce =
    es:
    let
      isMember = e: yen.lib.holds yen.kinds.member e.from;
      overrides = map (e: e.value) (lib.filter (e: !isMember e) es);
      keyOf = x: "${x.service}:${x.instance}:${x.role}:${x.machine}";
      own = map (e: {
        inherit (e.from) service instance role;
        machine = e.from.parent.name;
        inherit (e) value;
      }) (lib.filter isMember es);
      over = x: lib.findFirst (o: keyOf o == keyOf x) null overrides;
      allowed = x: yen.helpers.clan.services.${x.service}.exports or [ ];
    in
    {
      value = map (x: if over x != null then x // { inherit (over x) value; } else x) own;
      errors = lib.concatMap (
        x:
        map (k: {
          error = "clan: ${keyOf x}: service ${x.service} does not export ${k}";
          from = "fleet:main";
        }) (lib.subtractLists (allowed x) (lib.attrNames x.value))
      ) own;
    };
  yen.aspects.clan-extra-modules = {
    at = yen.lib.all [
      yen.kinds.member
      (s: s.extraModules != [ ])
    ];
    os =
      { member, ... }:
      {
        imports = member.extraModules;
      };
  };

  # clan's instance contract: known service and roles, at least one role, machine and instance counts, typed settings
  yen.aspects.clan-contract = {
    at = yen.kinds.fleet;
    errors =
      { ... }:
      lib.concatLists (
        lib.mapAttrsToList (
          n: i:
          let
            svc = service i;
            c = svc.constraints or { };
            count =
              r:
              lib.length (lib.filter (roleHas i.roles.${r}) (lib.attrValues yen.host ++ lib.attrValues yen.mac));
          in
          if svc == null then
            [ "clan: instance ${n} uses unknown service ${i.module}" ]
          else
            lib.optional (i.roles == { }) "clan: instance ${n} has no roles"
            ++ map (r: "clan: instance ${n}: service ${i.module} has no role ${r}") (
              lib.attrNames (removeAttrs i.roles (lib.attrNames svc.roles))
            )
            ++ lib.concatMap (
              r:
              let
                k = count r;
                lim = c.roles.${r} or { };
              in
              lib.optional (
                lim ? min && k < lim.min
              ) "clan: instance ${n} role ${r}: ${toString k} machines, at least ${toString lim.min}"
              ++ lib.optional (
                lim ? max && k > lim.max
              ) "clan: instance ${n} role ${r}: ${toString k} machines, at most ${toString lim.max}"
            ) (lib.attrNames (lib.intersectAttrs svc.roles i.roles))
            ++ lib.optional (
              c ? maxInstances
              && lib.length (lib.attrNames (lib.filterAttrs (_: j: j.module == i.module) all)) > c.maxInstances
            ) "clan: instance ${n}: service ${i.module} allows ${toString c.maxInstances} instances"
        ) all
      );
  };
  # a tag that names no machine is a warning, not an error (clan resolveTags): a user sink anyone may read
  yen.kinds.fleet.sinks.warnings.reduce = yen.lib.reduce.list;
  yen.aspects.clan-unknown-tags = {
    at = yen.kinds.fleet;
    warnings =
      { ... }:
      lib.concatLists (
        lib.mapAttrsToList (
          n: i:
          lib.concatLists (
            lib.mapAttrsToList (
              r: role:
              map (t: "clan: instance ${n} role ${r}: tag ${t} matches no machine") (
                lib.filter (
                  t: !lib.any (m: lib.elem t (labelsOf m)) (lib.attrValues yen.host ++ lib.attrValues yen.mac)
                ) (role.tags or [ ])
              )
            ) i.roles
          )
        ) all
      );
  };
  yen.aspects.clan-settings-typed = {
    at = yen.kinds.member;
    errors =
      { member, ... }:
      lib.concatLists (
        lib.mapAttrsToList (
          k: o:
          lib.optional (
            member.settings.${k} == null || !o.type.check member.settings.${k}
          ) "clan: ${member.instance}.${member.role}: setting ${k} is not a ${o.type.description}"
        ) (yen.helpers.clan.services.${member.service}.roles.${member.role}.interface or { })
      );
  };
}
