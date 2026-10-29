# den-hoag A8/A14/A10: aspect settings in layers with authority, and an aspect that projects settings onto other aspects.
# In yen a layer is an element, and the merge order is a reduce strategy you write (a "discipline" is a function).
{ yen, lib, ... }:
let
  # authority: each element is { rank; set; }. Higher rank wins per key (Leijen `shadow`); equal ranks must agree.
  layers =
    es:
    let
      sorted = lib.sort (a: b: a.value.rank < b.value.rank) es;
    in
    {
      value = lib.foldl' (acc: e: lib.recursiveUpdate acc e.value.set) { } sorted;
      errors = lib.concatLists (
        lib.imap0 (
          i: a:
          lib.concatMap (
            b:
            lib.optional
              (
                a.value.rank == b.value.rank
                && lib.intersectAttrs a.value.set b.value.set != lib.intersectAttrs b.value.set a.value.set
              )
              {
                error = "aspect-settings: two layers of rank ${toString a.value.rank} disagree";
                from = a.from.id;
              }
          ) (lib.drop (i + 1) es)
        ) es
      );
    };
  rank = {
    schema = 0;
    contains = 1;
    slice = 2;
    policy = 3;
  };
in
{
  yen.kinds.host.sinks.aspect-settings.reduce = layers;
  yen.aspects.nginx.aspect-settings = {
    rank = rank.schema;
    set.nginx = {
      workers = 1;
      gzip = true;
    };
  }; # the aspect's own default
  yen.aspects.env-tuning = {
    at = yen.lib.all [
      yen.kinds.host
      (yen.lib.within yen.environment.prod)
    ];
    aspect-settings = {
      rank = rank.contains;
      set.nginx.workers = 4;
    };
  };
  yen.aspects.web1-tuning = {
    at = yen.host.web-1;
    aspect-settings = {
      rank = rank.slice;
      set.nginx.workers = 8;
    };
  };
  # a projector: onto every aspect present here that declares settings (its own schema-rank layer)
  yen.aspects.no-gzip = {
    at = yen.host.stage;
    aspect-settings =
      { scope, ... }:
      {
        rank = rank.policy;
        set =
          lib.genAttrs
            (lib.filter (
              n:
              (yen.aspects.${n}.aspect-settings.rank or null) == rank.schema
              && yen.lib.holds yen.aspects.${n} scope
            ) (lib.attrNames yen.aspects))
            (_: {
              gzip = false;
            });
      };
  };
  yen.aspects.nginx-tuned = {
    # the narrow accessor: present (holds) + settings (the sink value)
    at = yen.aspects.nginx;
    nixos =
      { aspect-settings, ... }:
      {
        services.nginx.appendConfig = "worker_processes ${toString aspect-settings.nginx.workers};";
        services.nginx.recommendedGzipSettings = aspect-settings.nginx.gzip;
      };
  };
}
