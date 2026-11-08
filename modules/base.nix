{ config, pkgs, ... }:

{
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    htop
    rsync
    tmux
    direnv
  ];

  # direnv hooks into shell to run .envrc on cd
  programs.direnv.enable = true;

  # Flake-based auto-upgrade.
  # TODO: Add health checks / alerting before allowing unattended reboots.
  # In particular, verify Tailscale is healthy before rebooting — if the
  # Tailscale key has expired, a reboot will make SSH unreachable (port 22
  # is only on tailscale0). Rescue console would be the only recovery path.
  system.autoUpgrade = {
    enable = true;
    # Private repo → fetch over SSH with root's deploy key (/root/.ssh/id_ed25519).
    # The `github:` shorthand fetches via HTTPS and would need an access token instead.
    flake = "git+ssh://git@github.com/REPLACE_ME/REPLACE_ME";
    flags = [
      "--update-input" "nixpkgs"
    ];
    allowReboot = true;
    dates = "04:00";
    randomizedDelaySec = "30min";
  };

  # Enable flakes system-wide
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };
}
