{
  title = "Secrets as data";
  description = "Secrets are instances of a data kind. Hosts get exactly the secrets that name them, as refs.";
  section = "recipes";
  order = 6;

  body =
    {
      docs,
      result,
      variant,
      ...
    }:
    [
      ''
        yen never reads a secret. It plans which host gets which encrypted file, as data that a secrets tool
        (agenix, sops-nix) reads. A secret is an instance of a data kind; its owners are host refs.
      ''
      (docs.fileWith "{12-17}" "modules/kinds.nix")
      (docs.file "modules/data.nix")
      ''
        One component delivers each secret to its owners. Another reports secrets that nobody owns:
      ''
      (docs.file "modules/deliver.nix")
      (docs.tabs [
        {
          label = "secretsPlan";
          body = docs.value result.flake.secretsPlan;
        }
        {
          label = "errors";
          body = docs.value (map (e: e.error) result.errors);
        }
      ])
      ''
        ## Refs, not names

        The sink's `of` is the secret kind, so only a ref passes. A name is refused, with the scope and the aspect:
      ''
      (docs.file "variants/by-name.nix")
      (docs.value (map (e: e.error) (variant "variants/by-name.nix").errors))
      (docs.tip "Guard who may read" ''
        The plan is data, so a rule about it is a query. The [reference fleet](https://github.com/vic/yen/blob/main/templates/fleet/modules/clan/vars.nix)
        adds shared and per-machine generators, a deploy plan, and a guard that refuses a secret read by the wrong host.
      '')
    ];

  errors = true; # old-token has no owner, on purpose

  checks =
    { result, variant, ... }:
    {
      web =
        map (s: s.name) result.flake.secretsPlan.web == [
          "db-password"
          "tls"
        ];
      orphan =
        map (e: e.error) result.errors == [ "secret old-token (secrets/old-token.age) has no owner" ];
      by-name = builtins.length (variant "variants/by-name.nix").errors == 2;
    };
}
