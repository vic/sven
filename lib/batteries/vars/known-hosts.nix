#: lib.batteries.vars.known-hosts :: { from; rootOf; entry; keep ? ; } -> { nixos; errors } -- programs.ssh.knownHosts from public host keys in vars
# known hosts from public vars (see public-value): each entry of sink `from` that `keep scope entry` takes and
# `entry` names (`entry e` is `{ host; machine; generator; file; }`, or null: no host key) becomes a knownHosts record,
# the key read from `rootOf scope`/<machine>/<generator>/<file>/value. The battery names no field of the entries.
# A key file that is missing is an error record and no record, never a throw. `nixos` is the value for a nixos key,
# `errors` for an errors key.
#   kh = vars.known-hosts { from = yen.kinds.fleet.sinks.exports; rootOf = s: s.settings.root;
#     entry = e: { host = e.machine.name; machine = e.machine.name; inherit (e.value.hostKey) generator file; }; };
{
  from,
  rootOf,
  entry,
  keep ? scope: e: true,
}:
let
  b = builtins;
  pub = import ./public-value.nix;
  pick =
    { scope, sinks, ... }:
    map (
      k:
      let
        root = rootOf scope; # null: the setting is unset, settings-typed says so
      in
      {
        inherit k;
        key = if root == null then null else pub { inherit root; } k.machine k.generator k.file null;
      }
    ) (b.filter (k: k != null) (map entry (b.filter (e: keep scope e) sinks.${from.__sink})));
in
{
  nixos =
    { scope, sinks, ... }@args:
    {
      programs.ssh.knownHosts = b.listToAttrs (
        map (h: {
          name = h.k.host;
          value = {
            hostNames = [ h.k.host ];
            publicKey = h.key;
          };
        }) (b.filter (h: h.key != null) (pick args))
      );
    };
  errors =
    { scope, sinks, ... }@args:
    map (h: {
      error = "known-hosts: ${h.k.host} has no ${h.k.generator}/${h.k.file} public key";
    }) (b.filter (h: h.key == null) (pick args));
}
