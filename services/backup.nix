{ config, pkgs, ... }:

# SQLite snapshots for the app.
#
# Every 5 minutes: `VACUUM INTO` a timestamped copy under
# /var/lib/app/backups/, then prune anything older than 30 days. The DB is
# kilobytes-to-megabytes, so a month of 5-minute snapshots stays well under a
# gigabyte — and 5 minutes is the most event data we can ever lose.
#
# Restore: stop the app, copy a snapshot over /var/lib/app/app.sqlite3
# (removing any -wal/-shm files), start the app.

{
  systemd.services.app-backup = {
    description = "Snapshot the app's sqlite database";
    serviceConfig = {
      Type = "oneshot";
      User = "app";
      Group = "app";
      WorkingDirectory = "/var/lib/app";
    };
    script = ''
      db=/var/lib/app/app.sqlite3
      dir=/var/lib/app/backups
      # Nothing to back up before the app's first boot.
      [ -f "$db" ] || exit 0
      ${pkgs.sqlite}/bin/sqlite3 "$db" \
        "VACUUM INTO '$dir/db-$(date +%Y%m%d-%H%M%S).sqlite3'"
      # Retention: 30 days.
      find "$dir" -name 'db-*.sqlite3' -type f -mtime +30 -delete
    '';
  };

  systemd.timers.app-backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:0/5";       # every 5 minutes
      Persistent = true;          # catch up after downtime
      RandomizedDelaySec = 15;    # don't sync exactly with anything else
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/app/backups 0750 app app -"
  ];
}
