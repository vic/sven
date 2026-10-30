{ yen, lib, ... }:
let
  hosts.instances = yen.kinds.host; # a tree request: every host, with its data
in
{
  yen.aspects.report = {
    at = yen.kinds.host;
    cycle =
      { tree, scope, ... }:
      let
        host = scope;
        hs = lib.head (tree.select hosts);
      in
      {
        tree = [ hosts ];
        report = [
          {
            ${host.name} = {
              fqdn = "${host.name}.${host.environment.domain}"; # follow a ref, read its fields
              backup = if host.backup == null then null else host.backup.name;
              # `same` compares two instances by kind and name
              peers = map (h: h.name) (
                lib.filter (h: !yen.lib.same h host && yen.lib.same h.environment host.environment) hs
              );
            };
          }
        ];
      };
  };
}
