# Hardened NixOS server

A flake-based, security-hardened NixOS configuration for a single VPS that
hosts a web app behind Caddy. Provider-agnostic: anything that can boot NixOS
works.

It comes from a running server with its identity taken out: domains, keys,
password hashes and repo URLs are `REPLACE_ME` placeholders, and the host is
called `server`.

> `minimal.nix` is a lightweight bootstrap config for the initial install.
> See [DEPLOYMENT.md](DEPLOYMENT.md) for the full setup, including how to
> give a collaborator access.

## Structure

```
.
├── flake.nix                    # Entry point, inputs, outputs
├── configuration.nix            # Main config, imports all modules
├── hardware-configuration.nix   # Generated per-server (gitignored)
├── minimal.nix                  # Bootstrap config for initial install
├── modules/
│   ├── base.nix                 # Boot, packages, auto-upgrade
│   ├── networking.nix           # Firewall, SSH, fail2ban, Tailscale
│   ├── users.nix                # User accounts + SSH keys
│   ├── security.nix             # Hardening: sysctl, audit, sudo
│   └── rust.nix                 # Optional build toolchain (drop if unused)
└── services/
    ├── caddy.nix                # Reverse proxy, TLS, security headers, www → apex
    ├── server.nix               # The app service (sandboxed, neutral template)
    ├── backup.nix               # 5-minute SQLite snapshots of the app's DB
    ├── static.nix               # Example: static site pushed by CI, behind a password
    └── logs.nix                 # journald, logrotate
```

## Before you deploy — replace these

Every spot that needs your input is marked `REPLACE_ME`:

```bash
grep -rn REPLACE_ME .
```

At minimum: your SSH pubkey (`modules/users.nix`, `minimal.nix`), your domain
and ACME email (`services/caddy.nix`), and the auto-upgrade flake URL once you
push this repo (`modules/base.nix`). `services/static.nix` needs a CI key, a
domain and a password hash, or drop its import from `configuration.nix`.

## Security features

- **SSH**: key-only, modern ciphers with post-quantum key exchange first,
  **reachable only over Tailscale**
- **Firewall**: whitelist only (22 via tailscale0; 80, 443 and UDP 443 for
  HTTP/3 public)
- **Kernel**: hardened sysctl (IPv4 + IPv6), blacklisted modules
- **Services**: systemd sandboxing (PrivateTmp, ProtectSystem, syscall filter);
  app secrets in an `EnvironmentFile` outside the world-readable Nix store
- **Web**: HSTS, CSP and other security headers at the proxy
- **Audit**: tracks changes to passwd, shadow, sudoers, sshd_config
- **Updates**: auto-upgrade from the flake daily, weekly GC

## Gotchas this config already handles

- **HTTP/3 needs UDP 443 open.** Caddy advertises `alt-svc: h3`; if the port
  is closed, returning browsers try QUIC, hang until timeout, then fall back,
  which looks like intermittent TLS errors and slow loads.
- **`www` needs its own vhost.** Without one, visitors to `www.` get a TLS
  handshake error instead of a redirect.
- **Key-only accounts can't be password-less with `UsePAM = false`.** sshd
  refuses locked (`!`) accounts even for key logins, so a CI user gets the
  hash of a random, discarded string (see `services/static.nix`).
- **A private flake repo needs SSH for auto-upgrade.** `system.autoUpgrade`
  runs as root and the `github:` shorthand fetches over HTTPS, so use a
  `git+ssh://` URL and a deploy key in `/root/.ssh`.
- **Tailscale has to be up before the first full rebuild**, since that locks
  SSH to `tailscale0`. `minimal.nix` ships it for exactly that reason.

## Collaborator access (the short version)

SSH is Tailscale-only, which is the clean path for sharing the box:

1. Add their account + pubkey in `modules/users.nix`.
2. Add their username to `AllowUsers` in `modules/networking.nix`.
3. Share the node to them on your tailnet (or add them to it).
4. Rebuild.

Full walkthrough in [DEPLOYMENT.md](DEPLOYMENT.md).

## Quick reference

```bash
# Rebuild from local changes
sudo nixos-rebuild switch --flake .#server

# Service status / logs
systemctl status app caddy fail2ban
journalctl -u app -f
journalctl -u caddy -f

# fail2ban + audit log
sudo fail2ban-client status
sudo ausearch -k passwd_changes
```

## License

MIT, see [LICENSE](LICENSE).
