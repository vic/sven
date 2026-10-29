# A desktop on a server, and a new host with a copied address.
{ yen, ... }:
{
  yen.aspects.desktop.at = yen.host.web;
  yen.host.spare = {
    addr = "10.0.0.2";
    form = "server";
  };
}
