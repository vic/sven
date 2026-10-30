#: lib.batteries.vars.public-value :: { root; } -> machine -> generator -> file -> default -> string -- a public var read at eval time
# a public var read at eval time: root/<machine>/<generator>/<file>/value without its final newline, or `default`.
#   pub = clan.public-value { root = ./vars/per-machine; };   pub "lb" "openssh" "ssh.id_ed25519.pub" "absent"
{ root }:
m: gen: file: default:
let
  b = builtins;
  p = root + "/${m}/${gen}/${file}/value";
  s = b.readFile p;
  n = b.stringLength s;
in
if !b.pathExists p then
  default
else if n > 0 && b.substring (n - 1) 1 s == "\n" then
  b.substring 0 (n - 1) s
else
  s
