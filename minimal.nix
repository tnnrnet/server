{ config, pkgs, ... }:
# Bootstrap config for the very first install. Gets the box online with
# public-IP SSH + Tailscale, so you can authenticate Tailscale and then
# switch to the full hardened flake (see DEPLOYMENT.md).
{
  imports = [ ./hardware-configuration.nix ];

  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  networking.hostName = "server";
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAA... REPLACE_ME"
    ];
  };
  users.users.root.hashedPassword = "!";

  services.openssh = {
    enable = true;
    ports = [ 22 ];
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      X11Forwarding = false;
      UsePAM = false;
    };
    extraConfig = ''
      AllowUsers admin
    '';
  };

  # Tailscale must be available before the first full rebuild, which locks
  # SSH to the tailscale0 interface. Without this, there's no way to run
  # `tailscale up` and authenticate before losing public-IP SSH access.
  services.tailscale.enable = true;

  environment.systemPackages = with pkgs; [
    vim
    git
    curl
  ];

  system.autoUpgrade = {
    enable = true;
    allowReboot = false;
  };

  security.sudo.execWheelOnly = true;
  system.stateVersion = "25.05";
}
