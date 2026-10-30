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
    check = (removeAttrs r.check [ "why" ]) // {
      why = builtins.listToAttrs (
        map (v: {
          name = builtins.toJSON v; # a violation is a tuple: its JSON names it
          value = r.check.why v;
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
    why_not = {
      holds = builtins.elem args.atom r.check.violations;
      whyNot = r.check.whyNot args.atom;
      why = r.check.why args.atom;
    };
    program = yen.lib.program.dryRun {
      inherit base;
      result = r;
      prog = args.program;
    };
  };
in
safe tools.${env "YEN_TOOL"}
