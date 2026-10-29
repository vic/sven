# Batteries: functions from roles to a yen module. A battery names no kind, sink, aspect or field: the user passes
# each name, in its own words. Builtins only.
#   imports = [ (yen.lib.batteries.pool { on = "box"; as = "unfree"; into = "nixos"; set = names: …; }) ];
let
  b = builtins;
  # nixpkgs lib.setFunctionArgs shape: yen fills the named args of a functor (default.nix `fnArgs`)
  withArgs = args: f: {
    __functor = _: f;
    __functionArgs = args;
  };
  # a kind name that no scope can have would make the battery a silent no-op: make it a violation instead
  scoped = id: kind: {
    yen.invariants.${id} =
      { yen, ... }:
      if
        yen.kinds.${kind} ? spawns || b.any (k: (k.spawns or { }) ? ${kind}) (b.attrValues yen.kinds)
      then
        [ ]
      else
        [
          {
            head = "bad:no-scope-of-kind:${kind}";
            pos = [ ];
          }
        ];
  };
in
{
  # a sink `as` on kind `on` collects elements; `set` turns the reduced value into one element of sink `into`
  pool =
    {
      on,
      as,
      into,
      set,
      reduce ? null,
    }:
    {
      imports = [ (scoped "battery-${on}-${as}" on) ];
      yen.kinds.${on}.sinks.${as} = {
        ${into} = withArgs { ${as} = false; } (a: set a.${as});
      }
      // (if reduce == null then { } else { inherit reduce; });
    };

  # an aspect at `at` whose `into` content is `body scope`: the body reads the scope's fields, never an arg name
  gated =
    {
      name,
      at,
      into,
      body,
    }:
    {
      yen.aspects.${name} = {
        inherit at;
        ${into} = { scope, ... }: body scope;
      };
    };

  # a kind whose sink `as` builds a flake output: `out scope value`
  system =
    {
      kind,
      as,
      out,
    }:
    {
      imports = [ (scoped "battery-${kind}-${as}" kind) ];
      yen.kinds.${kind}.sinks.${as}.out = withArgs {
        scope = false;
        ${as} = false;
      } (a: out a.scope a.${as});
    };
}
