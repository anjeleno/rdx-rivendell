#!/usr/bin/env bash
set -euo pipefail

# Always write to rd's user crontab
USER_RD=rd
if ! id -u "$USER_RD" >/dev/null 2>&1; then
    echo "User '$USER_RD' does not exist; creating..."
    useradd -m -s /bin/bash "$USER_RD"
fi

add_line() {
    local when="$1"; shift
    local cmd="$1"; shift || true
    # preserve existing, append if missing
    (crontab -u "$USER_RD" -l 2>/dev/null | grep -v "$cmd"; echo "$when $cmd") | crontab -u "$USER_RD" -
}

add_line "05 00 * * *" "/home/rd/imports/APPS/sql/daily_db_backup.sh"
echo "Cron job for daily_db_backup.sh added/ensured for user '$USER_RD'"

add_line "15 00 * * *" "/home/rd/imports/APPS/autologgen.sh"
echo "Cron job for autologgen.sh added/ensured for user '$USER_RD'"

echo "All cron jobs ensured for user '$USER_RD'."