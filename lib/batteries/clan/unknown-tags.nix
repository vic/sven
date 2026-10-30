# clan resolveTags: a tag that matches no machine. A list of messages, for a warnings sink (it is no error).
#   warnings = clan.unknown-tags { inherit instances; machines = attrValues yen.host; labelsOf = …; };
{
  instances,
  machines,
  labelsOf ? m: m.labels or [ ],
}:
let
  b = builtins;
in
b.concatMap (
  n:
  b.concatMap (
    r:
    map (t: "clan: instance ${n} role ${r}: tag ${t} matches no machine") (
      b.filter (t: !b.any (m: b.elem t (labelsOf m)) machines) (instances.${n}.roles.${r}.tags or [ ])
    )
  ) (b.attrNames instances.${n}.roles)
) (b.attrNames instances)
