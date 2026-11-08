# Deployment Guide

## Quick Reference

```bash
cd /etc/nixos
sudo git pull --rebase
sudo nixos-rebuild switch --flake .#server
```

---

**Starting point:** a fresh VPS running NixOS with `minimal.nix` at `/etc/nixos`,
reachable via `ssh admin@<SERVER_IP>`.

**Before anything:** `grep -rn REPLACE_ME .` and fill in every placeholder
(SSH keys, domain, ACME email, flake URL).

**Prerequisites:** after the first full rebuild, SSH is via Tailscale only.
Complete Step 0 before that point.

## Steps

### 0. Set Up Tailscale

SSH in over the public IP (Tailscale ships in `minimal.nix`):

```bash
ssh admin@<SERVER_IP>
sudo tailscale up
```

Complete the browser auth, then disable key expiry for this node in the
[Tailscale admin console](https://login.tailscale.com/admin/machines).

Verify from your machine before proceeding:

```bash
ssh server   # using a ~/.ssh/config Host entry pointed at the tailnet name
```

After the first full rebuild (Step 4), SSH is **only** on the Tailscale interface.

### 1. Set Up Deploy Key (if the repo is private)

This is the **infra** repo's key (`<owner>/<this-repo>`). The nightly
`system.autoUpgrade` fetches the flake over SSH and runs as **root**, so its
key must live under `/root/.ssh`:

```bash
sudo mkdir -p /root/.ssh
sudo vi /root/.ssh/id_ed25519     # paste deploy key private key
sudo chmod 600 /root/.ssh/id_ed25519
```

> The **site** repo (`<owner>/<site-repo>`) uses a *separate* deploy key under
> the `admin` user — see "Deploy key (site repo)" below. Don't reuse the root
> key; the two repos are distinct and the site flow never touches root.

### 2. Replace Bootstrap Config with This Repo

```bash
cd /etc/nixos
sudo mv configuration.nix configuration.nix.bak
sudo git init
sudo git remote add origin <YOUR_REPO_URL>
sudo git fetch origin
sudo git checkout -f main
sudo git branch --set-upstream-to=origin/main main
```

> This repo keeps the flake at its root, so it clones straight to `/etc/nixos`
> and rebuilds with `.#server` — no subdir juggling.

### 3. Commit Server-Specific Files Locally

Each server needs its own `hardware-configuration.nix` and `flake.lock`.
They're gitignored — commit locally, never push:

```bash
sudo nixos-generate-config --show-hardware-config | sudo tee hardware-configuration.nix
sudo git add -f hardware-configuration.nix
sudo git commit -m "Add server hardware config (local only)"

sudo nix flake update
sudo git add -f flake.lock
sudo git commit -m "Add flake.lock (local only)"
```

> When pulling updates later, use `git pull --rebase` to keep these local
> commits on top. Remove `configuration.nix.bak` once the new config works.

### 4. Switch to the Full Configuration

Run inside `tmux` so it survives an SSH drop:

```bash
tmux
sudo nixos-rebuild switch --flake /etc/nixos#server
```

This activates all hardening, Caddy, the app service, fail2ban, etc.

> **Warning:** after this rebuild SSH is **only** reachable via Tailscale
> (port 22 is bound to `tailscale0`). Make sure Tailscale is authenticated
> and verified (Step 0) first. If your session drops mid-build, reconnect
> over Tailscale and `tmux attach`.

### 5. Post-Deploy Setup

```bash
sudo passwd admin          # console password for rescue access
direnv allow /etc/nixos    # command reminder on cd
```

### 6. Set Up DNS

Point your domain's A record at `<SERVER_IP>` (matching the host in
`services/caddy.nix`). Caddy auto-provisions TLS once DNS propagates.

### 7. Deploy Whatever You're Running

`services/server.nix` waits for an executable at `/var/lib/app/app` and
listens on `localhost:3000` (Caddy proxies to it). Build it however you
like — locally, in CI, or on the box — then:

```bash
scp ./your-binary admin@<host>:/tmp/app
ssh admin@<host> 'sudo install -o app -g app /tmp/app /var/lib/app/app && sudo systemctl restart app'
```

Adjust env/exec in `services/server.nix` to match what you actually run.

## Deploy key (site repo)

The site is its own private repo (`<owner>/<site-repo>`) and is
deployed by pulling + building **on the box as `admin`** (an `update.sh` in the site repo:
`git pull` → `cargo build --release` → `sudo install` → restart). Because the
pull runs as `admin`, the key lives under `admin`, *not* root — keep it
separate from the infra repo's auto-upgrade key in `/root/.ssh`.

1. **Generate a keypair** (passphraseless, so `update.sh` runs unattended):
   ```bash
   ssh-keygen -t ed25519 -f site_deploy_ed25519 -N "" -C "site-deploy@server"
   ```
2. **Register the public half** at `github.com/<owner>/<site-repo>` →
   Settings → Deploy keys → Add deploy key. Leave *Allow write access*
   **unchecked** — the box only pulls.
3. **Install the private half** as admin's default SSH identity:
   ```bash
   scp site_deploy_ed25519 admin@server:~/.ssh/id_ed25519
   ssh admin@server 'chmod 600 ~/.ssh/id_ed25519 \
     && ssh -o StrictHostKeyChecking=accept-new -T git@github.com; \
     git clone git@github.com:<owner>/<site-repo>.git ~/site'
   ```

Thereafter, deploying is just `cd ~/site && ./update.sh`.

## Collaborator Access

SSH is Tailscale-only, which is the clean way to share the box per-person:

1. **Account + key** — add them in `modules/users.nix` (uncomment the example,
   drop `wheel` if they shouldn't sudo).
2. **Allow SSH** — add their username to `AllowUsers` in `modules/networking.nix`.
3. **Tailnet** — share this node to them (Tailscale admin console → the machine →
   Share), or add them to your tailnet. They install Tailscale and `tailscale up`.
4. **Rebuild** — `sudo nixos-rebuild switch --flake .#server`.

For a larger group, generate Tailscale pre-auth keys instead of sharing one by
one. For the **config repo**, just add them as a collaborator wherever it's hosted.

> Avoid the temptation to reopen port 22 on the public firewall to skip the
> Tailscale step — it throws away the best property of this setup.

## Verification

```bash
systemctl status caddy app tailscale
curl -I https://<your-domain>
journalctl -u app -f
```

## Ongoing Updates

**Automatic:** the box pulls the flake daily at 04:00 and rebuilds.

**Manual:**

```bash
ssh server              # via Tailscale
cd /etc/nixos && sudo git pull --rebase
sudo nixos-rebuild switch --flake .#server
```

## Rescue Procedure

If locked out of SSH (e.g. Tailscale is down), use the provider's console:

1. Boot the rescue ISO from the provider console.
2. Mount and enter the system:
   ```bash
   mount /dev/sda1 /mnt
   nixos-enter
   ```
3. Pull latest config and rebuild for next boot:
   ```bash
   cd /etc/nixos
   git pull --rebase
   nixos-rebuild boot --flake /etc/nixos#server
   ```
4. `exit`, unmount the rescue ISO, `reboot`.
5. Once SSH is back: `sudo passwd admin` (persists across rebuilds with
   `mutableUsers = true`).
