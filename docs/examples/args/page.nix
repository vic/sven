{
  title = "Args";
  description = "An element can be a function with named args. yen fills kinds, sinks and `scope`; other args stay open.";
  section = "concepts";
  order = 11;

  body =
    {
      docs,
      r,
      variant,
      ...
    }:
    [
      ''
        An element can be a function with named args. yen fills the args it knows:
      ''
      (docs.table
        [ "Arg" "Value" ]
        [
          [
            "a kind name (`host`, `environment`)"
            "the nearest ancestor-or-self scope of that kind"
          ]
          [
            "a sink name (`backends`)"
            "the reduced value of that sink at its nearest receiver"
          ]
          [
            "`scope`"
            "the scope itself"
          ]
          [
            "anything else (`pkgs`, `config`)"
            "stays open: the element is still a function"
          ]
        ]
      )
      ''
        A load balancer reads the addresses that its environment collects:
      ''
      (docs.file "modules/fleet.nix")
      (docs.fileWith "{5,10}" "modules/aspects.nix")
      (docs.value r.flake.proxy)
      ''
        ## Optional and missing args

        `{ cluster ? null, ... }` makes an arg optional. Without a default, an arg with no answer means the element
        is not given, and `errors` says why:
      ''
      (docs.file "variants/missing.nix")
      (docs.value (variant "variants/missing.nix").errors)
      ''
        ## Open args: modules for NixOS and home-manager

        Args that yen does not know stay open. This is how a `nixos` element is a NixOS module: yen fills `host`,
        and NixOS fills `pkgs`, `config` and `lib` later.
      ''
      (docs.file "variants/open.nix")
      (docs.caution "Overlays" ''
        A bare `final: prev:` is a function of `final`, and yen has no `final`. That is an error.
        Wrap it: `{ ... }: final: prev: …`.
      '')
    ];

  checks =
    { r, variant, ... }:
    {
      proxy =
        r.flake.proxy.lb == [
          {
            at = "fleet:main/environment:prod/host:lb";
            backends = [
              "10.0.0.2"
              "10.0.0.3"
            ];
            cluster = "none";
            env = "prod";
          }
        ];
      missing = builtins.length (variant "variants/missing.nix").errors == 1;
      open =
        builtins.isFunction (builtins.elemAt (variant "variants/open.nix").flake.proxy.lb 1)
        || (builtins.elemAt (variant "variants/open.nix").flake.proxy.lb 1) ? __functor;
    };
}
