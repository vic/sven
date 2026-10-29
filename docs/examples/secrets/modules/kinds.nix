# A secret is data: nothing spawns it. A host's `secrets` sink only takes secret refs.
{ yen, lib, ... }:
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.secret.fields = {
    file = lib.types.str; # the encrypted file in the repo
    owners = yen.lib.is lib.isList; # host refs
  };
  yen.kinds.host.sinks.secrets = {
    reduce = yen.lib.reduce.set;
    of = yen.kinds.secret;
    # the plan a secrets tool reads: agenix, sops-nix, or your own
    out =
      { host, secrets, ... }:
      {
        secretsPlan.${host.name} = map (s: {
          inherit (s) name file;
          path = "/run/secrets/${s.name}";
        }) secrets;
      };
  };

  yen.fleet.main = { };
  yen.flake = { out, ... }: out;
}
