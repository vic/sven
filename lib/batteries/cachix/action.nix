# the GitHub Actions step of cachix/cachix-action for one cache: pushes what the job builds when `authToken` is set.
#   steps = [ … (cachix.action { name = "vix"; }) … ];
{
  name,
  authToken ? "\${{ secrets.CACHIX_AUTH_TOKEN }}",
  version ? "v17",
}:
{
  uses = "cachix/cachix-action@${version}";
  "with" = {
    inherit name authToken;
  };
}
