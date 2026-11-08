{ config, pkgs, lib, ... }:

# The application service.
#
# A neutral, sandboxed long-running service template — point it at whatever
# you need to run (a web app, an API, a worker, ...).
# It expects an executable at /var/lib/app/app and won't start until one is
# there, so the box boots cleanly before anything is deployed.
#
# Deploy by dropping a binary in place and restarting:
#   scp ./your-binary admin@<host>:/tmp/app
#   ssh admin@<host> 'sudo install -o app -g app /tmp/app /var/lib/app/app && sudo systemctl restart app'
#
# Listens on localhost:3000 by convention; Caddy reverse-proxies to it.
# Adjust the env/exec below to match what you actually run.

{
  # Dedicated, non-login system user with minimal permissions.
  users.users.app = {
    isSystemUser = true;
    group = "app";
    home = "/var/lib/app";
    createHome = true;
  };
  users.groups.app = {};

  systemd.services.app = {
    description = "Application service";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    # Skip gracefully until a binary is deployed.
    unitConfig.ConditionPathExists = "/var/lib/app/app";

    serviceConfig = {
      Type = "simple";
      User = "app";
      Group = "app";
      WorkingDirectory = "/var/lib/app";
      ExecStart = "/var/lib/app/app";
      Restart = "always";
      RestartSec = "5s";

      Environment = [
        "APP_ADDR=127.0.0.1:3000"
        "RUST_LOG=info"
      ];

      # Secrets (e.g. an ADMIN_TOKEN) live outside the
      # world-readable nix store. Optional ("-"): the service starts fine
      # without the file. Create it on the box:
      #   sudo install -o app -g app -m 600 /dev/null /var/lib/app/env
      #   echo 'ADMIN_TOKEN=...' | sudo tee /var/lib/app/env >/dev/null
      EnvironmentFile = "-/var/lib/app/env";

      # Hardening — also a decent baseline if you ever run untrusted code here.
      NoNewPrivileges = true;
      LockPersonality = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectKernelTunables = true;
      ProtectControlGroups = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      ReadWritePaths = [ "/var/lib/app" ];
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
      SystemCallFilter = [ "@system-service" "~@privileged" "~@resources" ];
      SystemCallArchitectures = "native";
      UMask = "0077";

      # Resource limits
      LimitNOFILE = 65536;
      LimitNPROC = 512;
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/app 0750 app app -"
  ];
}
