{ config, pkgs, ... }:

{
  networking.hostName = "server";

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 80 443 ];
    # HTTP/3 (QUIC). Caddy listens on UDP 443 and advertises
    # `alt-svc: h3` with a 30-day lifetime; if this port is dropped,
    # returning browsers try QUIC, hang until timeout, then fall back —
    # showing up as intermittent "SSL errors" / slow loads.
    allowedUDPPorts = [ 443 ];
    # SSH only accessible via Tailscale (see DEPLOYMENT.md "Collaborator access").
    interfaces.tailscale0.allowedTCPPorts = [ 22 ];
  };

  # TODO: Consider services.tailscale.authKeyFile for unattended setup.
  # Generate a single-use pre-auth key in the Tailscale admin console,
  # place it on the server during deploy key setup, and Tailscale
  # authenticates automatically on first rebuild — no interactive `tailscale up`.
  services.tailscale.enable = true;

  # Disable IPv6 if you're not using it (reduces attack surface)
  # networking.enableIPv6 = false;

  services.openssh = {
    enable = true;
    ports = [ 22 ];
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      X11Forwarding = false;
      UsePAM = false;

      # Modern crypto only
      Ciphers = [
        "chacha20-poly1305@openssh.com"
        "aes256-gcm@openssh.com"
        "aes128-gcm@openssh.com"
      ];
      # Post-quantum hybrids first (OpenSSH 9.9+/10.0 on nixos-25.05), then
      # classical curve25519 fallback for older clients. The hybrids combine
      # ML-KEM/sntrup with x25519, so they are at least as strong as the
      # classical fallback. Omitting them breaks PQ-required clients and
      # makes OpenSSH 10+ clients print a weak-crypto warning.
      KexAlgorithms = [
        "mlkem768x25519-sha256"
        "sntrup761x25519-sha512"
        "sntrup761x25519-sha512@openssh.com"
        "curve25519-sha256"
        "curve25519-sha256@libssh.org"
      ];
      Macs = [
        "hmac-sha2-512-etm@openssh.com"
        "hmac-sha2-256-etm@openssh.com"
      ];
    };
    # REPLACE_ME: list every account allowed to SSH in. Add collaborators here
    # *and* give them a key in modules/users.nix *and* share the node on your
    # tailnet. e.g.  AllowUsers admin alice bob
    extraConfig = ''
      AllowUsers admin deploy
      ClientAliveInterval 600
      ClientAliveCountMax 6
      MaxAuthTries 3
      MaxSessions 3
      LoginGraceTime 30
    '';
  };

  services.fail2ban = {
    enable = true;
    maxretry = 10;
    bantime = "10m";
    bantime-increment = {
      enable = true;
      maxtime = "24h";  # 1 day max
      factor = "2";
    };
    # SSH jail removed — port 22 is only reachable via Tailscale.
    # Add future jails here (e.g. Caddy rate limiting).
  };
}
