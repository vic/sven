# Generic batteries: functions from roles to a yen value. A battery names no kind, sink, aspect or field. You write the
# key, with refs where yen has them; the battery gives the value. Builtins only.
#   yen.kinds.host.sinks = yen.lib.batteries.pool { as = "unfree"; into = "nixos"; set = names: …; };
#   yen.aspects.hostname = yen.lib.batteries.gated { at = yen.kinds.host; into = "nixos"; body = s: …; };
let
  # nixpkgs lib.setFunctionArgs shape: yen fills the named args of a functor (default.nix `fnArgs`)
  withArgs = args: f: {
    __functor = _: f;
    __functionArgs = args;
  };
in
{
  # sinks: `as` collects elements; `set` turns the reduced value into one element of sink `into`
  pool =
    {
      as,
      into,
      set,
      reduce ? null,
    }:
    {
      ${as} = {
        ${into} = withArgs { ${as} = false; } (a: set a.${as});
      }
      // (if reduce == null then { } else { inherit reduce; });
    };

  # an aspect at `at` whose `into` content is `body scope`: the body reads the scope's fields, never an arg name
  gated =
    {
      at,
      into,
      body,
    }:
    {
      inherit at;
      ${into} = { scope, ... }: body scope;
    };

  # sinks: `as` builds a flake output, `out scope value`
  system =
    { as, out }:
    {
      ${as}.out = withArgs {
        scope = false;
        ${as} = false;
      } (a: out a.scope a.${as});
    };
}
