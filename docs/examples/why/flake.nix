{
  inputs.yen.url = "github:vic/yen";
  outputs = inputs: inputs.yen.lib.mkFlake { } ./modules/hello.nix;
}
