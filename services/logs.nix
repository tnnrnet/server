{ config, pkgs, ... }:

{
  services.journald.extraConfig = ''
    Storage=persistent
    MaxRetentionSec=30d
    MaxFileSec=1d
    ForwardToSyslog=no
    Compress=yes
    SystemMaxUse=500M
  '';

  services.logrotate = {
    enable = true;
    settings = {
      "/var/log/caddy/*.log" = {
        frequency = "daily";
        rotate = 30;
        compress = true;
        delaycompress = true;
        notifempty = true;
        create = "0640 caddy caddy";
        sharedscripts = true;
        postrotate = "systemctl reload caddy 2>/dev/null || true";
      };
      "/var/log/sudo.log" = {
        frequency = "weekly";
        rotate = 12;
        compress = true;
        delaycompress = true;
        notifempty = true;
        create = "0600 root root";
      };
    };
  };
}
