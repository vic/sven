{
  result,
  variant,
  eq,
  yes,
  ...
}:
let
  web = result.flake.config.web;
  has = re: x: builtins.any (e: builtins.match re e != null) (map (e: e.error) (variant x).errors);
in
{
  remote-builders = eq web.nix.buildMachines [
    {
      hostName = "10.0.0.3";
      speedFactor = 4;
      systems = [ "x86_64-linux" ];
    }
  ];
  nix-cache = {
    t1 = eq web.nix.settings.substituters [ "http://10.0.0.3:5000" ];
    t2 = eq web.nix.settings.trusted-public-keys [ "nas-cache-1:AAAA" ];
    t3 = eq result.flake.config.lb.nix.settings.substituters [ "http://10.0.0.3:5000" ];
    t4 = yes (builtins.any (f: f.file == "cache-key.pem") result.flake.varsPlan.nas.files);
    t6 = eq result.flake.config.nas.services.harmonia.signKeyPaths [
      "/run/secrets/vars/nix-cache-cache/cache-key.pem"
    ];
    t5 = yes (!builtins.any (f: f.file == "cache-key.pub") result.flake.varsPlan.nas.files);
  };
  monitoring = {
    t1 =
      eq
        (builtins.sort (a: b: a < b) (
          map (j: j.job_name) result.flake.config.lb.services.prometheus.scrapeConfigs
        ))
        [
          "nas"
          "web"
        ];
    t2 = eq web.services.prometheus.exporters.node.port 9100;
  };
  postgres = {
    t1 = eq result.flake.config.nas.services.postgresql.ensureDatabases [ "shop" ];
    t2 = eq web.environment.etc."postgres/shop.dsn".text "postgresql://shop@10.0.0.3:5432/shop";
    t3 = eq result.flake.config.nas.services.postgresql.authentication "host shop shop 10.0.0.2/32 trust\n";
    t4 = yes (!builtins.any (f: f.file == "password") result.flake.varsPlan.nas.files);
  };
  borg = {
    t1 = eq web.services.borgbackup.jobs.backup.repo "borg@10.0.0.3:/srv/web";
    t2 = eq web.services.borgbackup.jobs.backup.startAt "02:00";
  };
  wifi = {
    t3 = yes (!builtins.any (f: f.file == "psk.guest") result.flake.varsPlan.web.files); # only declared networks get a file
    t1 = eq web.environment.etc."wifi/networks".text "home office";
    t2 =
      eq
        (map (f: f.file) (builtins.filter (f: f.generator == "wifi.wifi") result.flake.varsPlan.web.files))
        [
          "psk.home"
          "psk.office"
        ];
  };
  two-servers = yes (has ".*cache2 role server: 2 machines, at most 1.*" "variants/two-servers.nix");
  no-key = yes (
    has ".*nix-cache: web has no nix-cache-cache5/cache-key.pub public key.*" "variants/no-key.nix"
  );
  no-server = yes (has ".*db2 role server: 0 machines, at least 1.*" "variants/no-server.nix");
  wrong-type = {
    t1 = yes (has ".*db3.client: setting user is not a string.*" "variants/wrong-type.nix");
    t2 = yes (has ".*cache3.server: setting port is not.*" "variants/wrong-type.nix");
  };
}
