{ yen, ... }:
{
  yen.aspects.accounts = {
    at = [
      yen.kinds.user
      yen.kinds.home
    ];
    os = { scope, ... }: "account ${scope.name}";
  };
  yen.aspects.records = {
    at = yen.kinds.host;
    dns = { host, ... }: "${host.name} A";
  };
}
