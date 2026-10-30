{
  title = "Caches and secrets batteries";
  description = "cachix caches trusted by hosts and the flake, pushed from CI; secretspec.toml and .sops.yaml from what each feature declares.";
  section = "batteries";
  route = "batteries/secrets";
  order = 7;

  body =
    {
      docs,
      result,
      ...
    }:
    let
      texts = builtins.foldl' (
        a: m: a // builtins.mapAttrs (_: f: f.text) m.files.file
      ) { } result.reduced.files."repo:main";
    in
    [
      ''
        | Battery | Value of | Gives |
        |---|---|---|
        | `cachix.caches { from; }` | a NixOS, nix-darwin or home-manager key of a sink of caches | `nix.settings` substituters and trusted keys |
        | `cachix.flake-config { from; }` | a flake-level key | flake `nixConfig` extra-substituters and keys |
        | `cachix.action { name; authToken; version; }` | a workflow step | `cachix/cachix-action`, which pushes what the job builds |
        | `secretspec.toml { from; project; defaults; providers; profiles; }` | a key that gives to the files sink | `secretspec.toml` ([cachix/secretspec](https://github.com/cachix/secretspec)) |
        | `secrets.sops-config { from; path; }` | the same | `.sops.yaml` from a sink of creation rules |

        A cache is `{ name; publicKey; url ? "https://<name>.cachix.org"; }`. A secret is `{ name; profile ? "default"; … }`
        with any secretspec field. With a `claim` reduce, a secret that two scopes declare is an error.
      ''
      (docs.file "modules/fleet.nix")
      (docs.file "modules/caches.nix")
      (docs.value result.flake.nixConfig)
      (docs.file "modules/secrets.nix")
      (docs.code "toml" texts."secretspec.toml")
      (docs.code "yaml" texts.".sops.yaml")
    ];

  checks =
    { result, ... }:
    let
      texts = builtins.foldl' (
        a: m: a // builtins.mapAttrs (_: f: f.text) m.files.file
      ) { } result.reduced.files."repo:main";
    in
    {
      flake-config = result.flake.nixConfig.extra-substituters == [ "https://nix-community.cachix.org" ];
      secretspec =
        texts."secretspec.toml"
        == "[defaults]\nproviders = [\"keyring\"]\n\n[profiles.default]\nDATABASE_URL = { description = \"PostgreSQL connection string\" }\n\n[profiles.development]\nDATABASE_URL = { default = \"sqlite://./dev.db\", required = false }\n\n[project]\nname = \"my-app\"\n";
      sops =
        texts.".sops.yaml"
        == "\"creation_rules\":\n  -\n    \"age\": \"age1db\"\n    \"path_regex\": \"secrets/db/.*\"\n";
      action =
        builtins.match ".*cachix/cachix-action@v17.*" (
          builtins.replaceStrings [ "\n" ] [ " " ] texts.".github/workflows/build.yml"
        ) != null;
    };

  e2e =
    { flake, ... }:
    let
      c = flake.nixosConfigurations.build.config;
    in
    {
      substituters = builtins.elem "https://nix-community.cachix.org" c.nix.settings.substituters;
      keys = builtins.any (
        k: builtins.substring 0 13 k == "nix-community"
      ) c.nix.settings.trusted-public-keys;
    };
}
