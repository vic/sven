#: lib.batteries.disko :: { from; } -> key value -- disko.devices from the disk layouts given to sink from
# the disk layout of this machine: `disko.devices` is the merge of what the scopes gave to sink `from` (reduce merge:
# `{ disk.<name> = …; }`; two different answers at one path are an error). Nothing given, nothing set.
#   nixos = disko { from = yen.kinds.host.sinks.disks; };
{ from }:
{ sinks, ... }:
let
  devices = sinks.${from.__sink};
in
if devices == { } then { } else { disko.devices = devices; }
