# tty autologin of the user that `user` reads from the scope: a ref (its name) or a name; null logs in nobody
# (Den's tty-autologin).
#   yen.aspects.autologin = { at = yen.kinds.host; nixos = nixos.autologin { user = h: h.autologin; }; };
{ user }:
{ scope, ... }:
let
  u = user scope;
  name =
    if u == null then
      null
    else if builtins.isAttrs u then
      u.name
    else
      u;
in
if name == null then { } else { services.getty.autologinUser = name; }
