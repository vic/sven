# the settings every role of a homelab needs; the variants reuse them so only the contract differs
yen: {
  device = "/dev/sda";
  layout = yen.layout.single-ext4;
  authorizedKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAdminKeyNotReal admin" ];
  hardware = ./hardware;
  prefix = "10.8.0.0/24";
}
