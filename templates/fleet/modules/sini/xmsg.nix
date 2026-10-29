# Trust graph: the filter lives with the reader.
{ yen, lib, ... }:
let
  trusts = e: user: !(yen.lib.same e.from user);
in
{
  yen.kinds.fleet.sinks.xmsg-nodes.reduce = yen.lib.reduce.entries;
  yen.aspects.xmsg = {
    at = yen.kinds.user;
    xmsg-nodes = { user, ... }: user.name;
    homeManager =
      { xmsg-nodes, user, ... }:
      {
        home.file.".xmsg-peers".text = builtins.toJSON (
          lib.unique (map (e: e.value) (lib.filter (e: trusts e user) xmsg-nodes))
        );
      };
  };
}
