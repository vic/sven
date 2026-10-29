# vix: secrets are a data kind (no scopes). Features give the secrets they need on the user's `secrets` sink.
{ yen, lib, ... }:
{
  yen.kinds.secret.fields.sopsKey = lib.types.str;
  yen.secret.gh-token.sopsKey = "github_token";
  yen.secret.gpg-key.sopsKey = "gpg_key";
  yen.kinds.user.sinks.secrets = {
    of = yen.kinds.secret;
    reduce = yen.lib.reduce.set;
    homeManager =
      { secrets, ... }:
      {
        home.file.".secrets".text = lib.concatMapStringsSep "\n" (s: s.sopsKey) secrets;
      };
  };
  yen.aspects.gh = {
    at = yen.kinds.user;
    secrets = yen.secret.gh-token;
  };
  yen.aspects.gpg = {
    at = yen.user.bob;
    secrets = yen.secret.gpg-key;
  };
}
