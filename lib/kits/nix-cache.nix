#: lib.kits.nix-cache :: { root; } -> module -- binary cache: a harmonia server and clients that trust the generated public key
# `root`: where public keys are read from. The server runs harmonia with the generated `cache-key.pem` (a path, never a
# value) and exports its url and the ref of the generated `cache-key.pub`. A client sets `nix.settings.substituters` and
# `trusted-public-keys` from that file; a server whose file is missing is an error record. Needs a machine field `addr`.
#   imports = [ (inputs.yen.lib.kits.nix-cache { root = ../../vars/per-machine; }) ];
{ root }:
{ yen, lib, ... }:
let
  inherit (yen.lib) all same;
  pub = yen.lib.batteries.vars.public-value { inherit root; };
  member =
    role:
    all [
      yen.kinds.member
      (s: same (s.kit or null) yen.kit.nix-cache && s.role == role)
    ];
  gen = a: "nix-cache-${a.name}"; # a generator name
  key = e: pub e.machine.name e.value.key.generator e.value.key.file null;
  servers = a: exports: lib.filter (e: same e.assembly a && e.role == "server") exports;
in
{
  yen.kit.nix-cache = {
    roles = {
      server.interface.port = {
        type = lib.types.port;
        default = 5000;
      };
      client = { };
    };
    constraints.roles.server = {
      min = 1;
      max = 1;
    };
    exports = [
      "url"
      "key"
    ];
  };
  yen.aspects.nix-cache-server = {
    at = member "server";
    exports =
      { scope, member, ... }:
      {
        url = "http://${scope.parent.addr}:${toString member.settings.port}";
        key = {
          generator = gen member.assembly;
          file = "cache-key.pub";
        };
      };
    generators =
      { member, ... }:
      {
        name = gen member.assembly;
        files = {
          "cache-key.pem".secret = true;
          "cache-key.pub".secret = false;
        };
      };
    errors =
      { member, exports, ... }:
      map (
        e: "nix-cache: ${e.machine.name} has no ${e.value.key.generator}/${e.value.key.file} public key"
      ) (lib.filter (e: key e == null) (servers member.assembly exports));
    nixos =
      { member, ... }:
      {
        services.harmonia = {
          enable = true;
          signKeyPaths = [ "/run/secrets/vars/${gen member.assembly}/cache-key.pem" ]; # a path only
          settings.bind = "[::]:${toString member.settings.port}";
        };
      };
  };
  yen.aspects.nix-cache-client = {
    at = member "client";
    nixos =
      { member, exports, ... }:
      let
        ss = servers member.assembly exports;
      in
      {
        nix.settings.substituters = map (e: e.value.url) ss;
        nix.settings.trusted-public-keys = lib.filter (k: k != null) (map key ss);
      };
  };
}
