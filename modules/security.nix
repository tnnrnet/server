{ config, pkgs, ... }:

{
  security.sudo = {
    execWheelOnly = true;
    extraConfig = ''
      Defaults    env_reset
      Defaults    secure_path="/run/wrappers/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin"
      Defaults    timestamp_timeout=15
      Defaults    logfile=/var/log/sudo.log
    '';
  };

  security.pam.services.su.requireWheel = true;

  boot.kernel.sysctl = {
    # IPv4 hardening
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv4.conf.default.accept_source_route" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.secure_redirects" = 0;
    "net.ipv4.conf.default.secure_redirects" = 0;
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
    "net.ipv4.icmp_ignore_bogus_error_responses" = 1;
    "net.ipv4.tcp_syncookies" = 1;
    "net.ipv4.conf.all.log_martians" = 1;
    "net.ipv4.conf.default.log_martians" = 1;

    # IPv6 hardening (if enabled)
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.default.accept_redirects" = 0;
    "net.ipv6.conf.all.accept_source_route" = 0;
    "net.ipv6.conf.default.accept_source_route" = 0;
    "net.ipv6.conf.all.accept_ra" = 0;
    "net.ipv6.conf.default.accept_ra" = 0;

    # Filesystem protections
    "fs.protected_hardlinks" = 1;
    "fs.protected_symlinks" = 1;
    "fs.protected_fifos" = 2;
    "fs.protected_regular" = 2;

    # Kernel hardening
    "kernel.randomize_va_space" = 2;
    "kernel.kptr_restrict" = 1;
    "kernel.yama.ptrace_scope" = 1;
    "kernel.dmesg_restrict" = 1;
    "kernel.perf_event_paranoid" = 3;
    "kernel.unprivileged_bpf_disabled" = 1;
    "kernel.sysrq" = 0;  # Disable magic SysRq (not needed on VPS)
    "vm.mmap_min_addr" = 65536;  # Prevent null pointer dereference exploits
    "net.core.bpf_jit_harden" = 2;
  };

  security = {
    auditd.enable = true;
    audit = {
      enable = true;
      rules = [
        "-w /etc/passwd -p wa -k passwd_changes"
        "-w /etc/shadow -p wa -k shadow_changes"
        "-w /etc/group -p wa -k group_changes"
        "-w /etc/sudoers -p wa -k sudoers_changes"
        "-w /etc/ssh/sshd_config -p wa -k sshd_config"
      ];
    };
    polkit.enable = true;
  };

  # Disable kernel modules we don't need on a VPS
  boot.blacklistedKernelModules = [
    "bluetooth"
    "btusb"
    "uvcvideo"    # webcam
    "snd_hda_intel"  # sound
    "snd_hda_codec"
    "firewire-core"
    "thunderbolt"
  ];
}
