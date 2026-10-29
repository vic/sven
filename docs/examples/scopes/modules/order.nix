# Siblings sort by the `order` sink (default 0), then by name. A parent comes before its children.
{ yen, ... }:
{
  yen.aspects.web-first = {
    at = yen.host.web;
    order = -1;
  };
}
