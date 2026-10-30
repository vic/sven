# AI agents: one extensions pool read by every agent, skills from directories.
{
  extensions = import ./extensions.nix;
  skills = import ./skills.nix;
}
