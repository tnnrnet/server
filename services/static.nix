{ config, pkgs, ... }:

# Static site deployed by CI (an example; drop the import in
# configuration.nix if you don't need it).
#
# A CI job builds the site and rsyncs it here over Tailscale as the `deploy`
# user: main at the root, each open PR under pr-N/. The CI side needs the
# private half of the key below, and to be on your tailnet (e.g. the
# tailscale/github-action with an ephemeral, tagged auth key). Who can see
# what is decided per path in the vhost below.

{
  # Owns the web root and nothing else; no sudo, no wheel. CI's key.
  users.users.deploy = {
    isNormalUser = true;
    shell = pkgs.bash;
    # A user with no password gets a locked ("!") shadow entry, and with
    # UsePAM off sshd refuses locked accounts even for key logins. So give it
    # the hash of a random string you then throw away: unusable, but not
    # locked. e.g.  head -c 32 /dev/urandom | base64 | mkpasswd -m sha-512 -s
    hashedPassword = "REPLACE_ME";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAA... REPLACE_ME"
    ];
  };

  systemd.tmpfiles.rules = [
    "d /srv/static-web 0755 deploy users -"
  ];

  # Caddy runs with ProtectSystem=strict and only needs to read this.
  # The whole site is behind a shared "preview" password, previews and root
  # alike (make the hash with `caddy hash-password`). To open the root to
  # everyone and keep only the PR previews private, give basic_auth a matcher:
  #   @previews path /pr-*
  #   basic_auth @previews { ... }
  services.caddy.virtualHosts."static.REPLACE_ME.example.com" = {
    extraConfig = ''
      root * /srv/static-web
      encode zstd gzip

      log {
        output file /var/log/caddy/access-static.log
      }

      # Big build outputs that change with every deploy: let browsers cache
      # them but always revalidate.
      @build path *.wasm *.js
      header @build Cache-Control "no-cache"

      basic_auth {
        preview REPLACE_ME
      }

      file_server
    '';
  };
}
