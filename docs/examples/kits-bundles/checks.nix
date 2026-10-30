{
  result,
  variant,
  eq,
  yes,
  ...
}:
let
  members = import ./members.nix result;
  has = re: x: builtins.any (e: builtins.match re e != null) (map (e: e.error) (variant x).errors);
  on = m: a: builtins.elem a (members.of m);
in
{
  # the server is the controller, the backup server, the monitor and the dns; the nodes are their peers
  server = {
    t1 = yes (on "nas" "lab-wg.controller");
    t2 = yes (on "nas" "lab-borg.server");
    t3 = yes (on "nas" "lab-monitoring.server");
    t4 = yes (on "nas" "lab-dns.default");
    t5 = yes (on "nas" "lab-borg-sshd.server"); # borg adds sshd
  };
  nodes = {
    t1 = yes (on "web" "lab-wg.peer" && on "lb" "lab-wg.peer");
    t2 = yes (on "web" "lab-borg.client" && on "lb" "lab-monitoring.exporter");
    t3 = yes (!on "web" "lab-dns.default" && !on "lb" "lab-borg.server");
  };
  base =
    eq
      (map (m: on m "lab-base-disko.default" && on m "lab-base-sshd.server") [
        "lb"
        "web"
        "nas"
      ])
      [
        true
        true
        true
      ];
  exports = eq (builtins.length members.exports) 10;
  two-servers = yes (has ".*lab2 role server: 2 machines, at most 1.*" "variants/two-servers.nix");
  no-server = yes (has ".*lab0 role server: 0 machines, at least 1.*" "variants/no-server.nix");
}
