# Recursive kinds: domains under domains. `parent` is a scope key, so the field is `under`.
{ yen, lib, ... }:
let
  inherit (yen.lib) maybe opt;
in
{
  yen.kinds.fleet.spawns.domain = _: lib.filterAttrs (_: d: d.under == null) yen.domain;
  yen.kinds.domain = {
    fields = {
      under = maybe yen.kinds.domain;
      mail.dkim = opt (yen.helpers.listOf lib.types.str) [ ];
      mail.enable = opt lib.types.bool false;
    };
    spawns.domain = s: lib.filterAttrs (_: d: d.under != null && yen.lib.same d.under s) yen.domain;
  };
  yen.kinds.fleet.sinks = {
    dns-records.reduce = yen.lib.reduce.entries;
    certificate-domains.of = lib.types.str;
  };
  yen.domain."example.org".mail.enable = true;
  yen.domain."api.example.org".under = yen.domain."example.org";
  yen.domain."v1.api.example.org".under = yen.domain."api.example.org";
  yen.aspects.domain-mail = {
    at = yen.lib.all [
      yen.kinds.domain
      (s: s.mail.enable)
    ];
    dns-records =
      { domain, ... }:
      {
        name = domain.name;
        type = "MX";
        content = "mail.protonmail.ch";
      };
  };
  yen.aspects.domain-tls = {
    at = yen.kinds.domain;
    certificate-domains = { domain, ... }: domain.name;
  };
}
