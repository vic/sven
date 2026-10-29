# A home-manager module reads its host and its user as args: no extraSpecialArgs, no osConfig.
{ yen, ... }:
{
  yen.aspects.prompt = {
    at = yen.lib.all [
      yen.kinds.user
      (yen.lib.within yen.kinds.host)
    ];
    homeManager =
      { host, user, ... }:
      {
        home.sessionVariables.PROMPT_TAG = "${user.name}@${host.name}";
      };
  };
}
