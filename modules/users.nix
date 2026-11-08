{ config, pkgs, ... }:

{
  # Each human who needs shell access gets an account here, a line in
  # services.openssh `AllowUsers` (modules/networking.nix), and a share on
  # your tailnet (SSH is Tailscale-only). See DEPLOYMENT.md.
  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAA... REPLACE_ME"
    ];
  };

  # Example collaborator — uncomment, add their key, and add `alice` to
  # AllowUsers in modules/networking.nix. Drop `wheel` if they shouldn't sudo.
  # users.users.alice = {
  #   isNormalUser = true;
  #   extraGroups = [ "wheel" ];
  #   openssh.authorizedKeys.keys = [
  #     "ssh-ed25519 AAAA... alice-pubkey"
  #   ];
  # };

  # Lock root account entirely
  users.users.root.hashedPassword = "!";

  # Allow manually-set passwords to persist across rebuilds (for console access)
  users.mutableUsers = true;
}
