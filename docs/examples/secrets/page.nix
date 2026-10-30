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
      (docs.value result.flake.secretsPlan)
      ''
        A secret that nobody owns is an error, and a fleet with an error gives no outputs (`flake` is `null`):
      ''
      (docs.file "variants/orphan.nix")
      (docs.value {
        errors = map (e: e.error) (variant "variants/orphan.nix").errors;
        inherit (variant "variants/orphan.nix") flake;
      })
      ''
        ## Refs, not names

        The sink's `of` is the secret kind, so only a ref passes. A name is refused, with the scope and the aspect:
      ''
      (docs.file "variants/by-name.nix")
      (docs.value (map (e: e.error) (variant "variants/by-name.nix").errors))
      ''
        ## Values no answer states

        A field whose type is `yen.lib.secret t` is checked like `t`, and an aspect reads its value. No answer states it:
        facts, `data`, `scopes`, error records, the RDF export and the seal give `sha256:<hash>` instead. A rule can still
        compare two secrets, because equal values have equal hashes: "no two hosts share a token" is a rule.
      ''
      (docs.tip "Guard who may read" ''
        The plan is data, so a rule about it is a query. The [reference fleet](https://github.com/vic/yen/blob/main/templates/fleet/modules/kits/vars.nix)
        adds shared and per-machine generators, a deploy plan, and a guard that refuses a secret read by the wrong host.
      '')
    ];

  checks =
    {
      result,
      variant,
      eq,
      yes,
      no,
      ...
    }:
    {
      web = eq (map (s: s.name) result.flake.secretsPlan.web) ([
        "db-password"
        "tls"
      ]);
      orphan = {
        t1 = eq (map (e: e.error) (variant "variants/orphan.nix").errors) ([
          "secret old-token (secrets/old-token.age) has no owner"
        ]);
        t2 = eq ((variant "variants/orphan.nix").flake) (null);
      };
      by-name = eq (map (e: e.code) (variant "variants/by-name.nix").errors) ([ "of" ]);
    };
}
