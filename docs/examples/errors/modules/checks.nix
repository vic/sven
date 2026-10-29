# An aspect key `errors` gives error records, or plain messages. Nothing throws. `from` is always the giving scope.
{ yen, lib, ... }:
let
  byAddr = lib.groupBy (h: h.addr) (lib.attrValues yen.host);
in
{
  yen.aspects.unique-addr = {
    at = yen.kinds.fleet;
    errors = lib.concatLists (
      lib.mapAttrsToList (
        a: hs:
        lib.optional (lib.length hs > 1) {
          code = "duplicate-addr";
          error = "${a} is the address of ${lib.concatMapStringsSep " and " (h: h.name) hs}";
          fix = "give each host its own addr";
          path = [ "addr" ];
          got = a;
        }
      ) byAddr
    );
  };
  yen.aspects.no-backup = {
    at = yen.lib.all [
      yen.kinds.host
      (s: !s.backup)
    ];
    warnings = { host, ... }: "${host.name} has no backup";
  };
}
