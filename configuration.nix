{ config, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix   # generated per-server, gitignored
    ./modules/base.nix
    ./modules/networking.nix
    ./modules/users.nix
    ./modules/security.nix
    ./modules/rust.nix             # optional build toolchain — drop if not building on-server
    ./services/caddy.nix
    ./services/static.nix          # example: static site pushed by CI
    ./services/server.nix         # the long-running app/web service (whatever you run)
    ./services/backup.nix          # 5-minute sqlite snapshots of the app DB
    ./services/logs.nix
  ];

  system.stateVersion = "25.05";
}
