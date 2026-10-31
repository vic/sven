# One yen-mcp tool call. Inputs come from the environment, never from string interpolation:
# YEN_FLAKE (the fleet flake ref), YEN_FLEET (fleet dir), YEN_TOOL, YEN_ARGS (path of the arguments JSON).
let
  env = builtins.getEnv;
  fleet = /. + env "YEN_FLEET";
  inputs = (builtins.getFlake (env "YEN_FLAKE")).inputs;
  yen = inputs.yen;
  base = {
    imports = [ (inputs.import-tree (fleet + "/modules")) ];
    _module.args = {
      inherit inputs;
      inherit (inputs.nixpkgs) lib;
    };
  };
  r = yen.lib.eval base;
  safe = yen.lib.jsonSafe;
  args = builtins.fromJSON (builtins.readFile (env "YEN_ARGS"));
  opt =
    names:
    builtins.intersectAttrs (builtins.listToAttrs (
      map (n: {
        name = n;
        value = null;
      }) names
    )) args;
  tools = {
    schema = r.agent.schema;
    check =
      (removeAttrs r.check [
        "why"
        "bad"
        "facts"
        "relations"
      ])
      // {
        why = builtins.listToAttrs (
          map (v: {
            name = builtins.toJSON v; # a violation is a tuple: its JSON names it
            # asked back by reference: each scope id of the answer as its scope record
            value = r.check.why (
              r.check.bad.${builtins.elemAt v 1} (
                map (t: builtins.head (builtins.filter (s: s.id == t) r.scopes ++ [ t ])) (
                  builtins.tail (builtins.tail v)
                )
              )
            );
          }) r.check.violations
        );
      };
    context = r.context args.id (opt [
      "maxEdges"
      "maxAspects"
    ]);
    explain = r.explain args.aspect args.scope (args.depth or 3);
    errors = builtins.filter (e: !(args ? code) || (e.code or null) == args.code) r.agent.errors;
    declared_in = r.declaredIn args.path;
    export = yen.lib.rdf.share r;
    stage = removeAttrs (yen.lib.stage {
      inherit base;
      change = args.change;
    }) [ "render" ];
    queries = r.queries;
    ask = r.ask args.name (args.args or { });
    impact = r.impact args.id (opt [
      "hops"
      "sinks"
      "max"
    ]);
    labels = {
      labels = r.labels;
      floor =
        if args ? floor then
          map (e: {
            inherit (e) aspect trust file;
            inherit (e.edge) sink from to;
          }) (r.floor args.floor)
        else
          [ ];
    };
    # a violation by reference: { invariant; scope = { kind; name; }; }
    why_not =
      let
        l = r.check.bad.${args.invariant} args.scope;
      in
      if !(r.check.bad ? ${args.invariant}) then
        {
          error = "no invariant ${args.invariant}";
          code = "unknown-invariant";
          known = builtins.attrNames r.check.bad;
        }
      else
        {
          holds = r.check.whyNot l == [ ];
          whyNot = r.check.whyNot l;
          why = r.check.why l;
        };
    program = yen.lib.program.dryRun {
      inherit base;
      result = r;
      prog = args.program;
    };
  };
in
safe tools.${env "YEN_TOOL"}
