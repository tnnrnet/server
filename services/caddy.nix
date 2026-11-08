{ config, pkgs, ... }:

{
  services.caddy = {
    enable = true;

    globalConfig = ''
      # Email for ACME/Let's Encrypt
      email REPLACE_ME@example.com
    '';

    virtualHosts = {
      # DOMAIN: the site's hostname lives HERE and only here — the
      # app renders its own docs/links from the request Host header, so
      # switching domains is: change this key, rebuild, update DNS.
      "REPLACE_ME.example.com" = {
        extraConfig = ''
          # Security headers
          header {
            Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
            X-Frame-Options "DENY"
            X-Content-Type-Options "nosniff"
            Referrer-Policy "strict-origin-when-cross-origin"
            Permissions-Policy "geolocation=(), microphone=(), camera=()"
            # Defense-in-depth over the app's output escaping. 'unsafe-inline'
            # script is required by index.html's pre-paint theme script and
            # the importmap; data: img by the inline SVG favicon.
            Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'"
            -Server
          }

          # The app (single binary at /var/lib/app/app).
          reverse_proxy localhost:3000 {
            header_up X-Real-IP {remote_host}
            header_up X-Forwarded-For {remote_host}
            header_up X-Forwarded-Proto {scheme}
          }

          encode gzip zstd

          handle_errors {
            respond "{http.error.status_code} {http.error.status_text}"
          }
        '';
      };

      # www → apex. Requires a DNS A record for www pointing at this box;
      # Caddy then provisions a cert for it and redirects. Without this
      # vhost, www visitors get a TLS handshake "internal error".
      "www.REPLACE_ME.example.com" = {
        extraConfig = ''
          redir https://REPLACE_ME.example.com{uri} permanent
        '';
      };

      # Static site example (uncomment if needed)
      # "static.REPLACE_ME.example.com" = {
      #   extraConfig = ''
      #     root * /var/www/sites/static
      #     encode gzip
      #     file_server { browse off }
      #   '';
      # };
    };
  };

  # Harden Caddy's systemd service
  systemd.services.caddy.serviceConfig = {
    NoNewPrivileges = true;
    AmbientCapabilities = "CAP_NET_BIND_SERVICE";
    CapabilityBoundingSet = "CAP_NET_BIND_SERVICE";
    LockPersonality = true;
    PrivateDevices = true;
    PrivateTmp = true;
    ProtectKernelTunables = true;
    ProtectControlGroups = true;
    ProtectHome = true;
    ProtectSystem = "strict";
    ReadWritePaths = [ "/var/lib/caddy" "/var/log/caddy" "/var/www/sites" ];
  };

  # Directory structure
  systemd.tmpfiles.rules = [
    "d /var/www/sites 0755 caddy caddy -"
    "d /var/log/caddy 0750 caddy caddy -"
  ];
}
