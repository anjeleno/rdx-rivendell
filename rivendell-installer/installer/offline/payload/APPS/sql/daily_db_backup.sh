#!/usr/bin/env bash
set -euo pipefail

# Cron-safe PATH
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Configuration
BACKUP_RETENTION=14
BACKUP_DIR="/home/rd/imports/APPS/sql"
BACKUP_PREFIX="NIGHTLY_BACKUP"
LOG_FILE="${BACKUP_DIR}/cron_execution.log"

timestamp() { date -u +%Y-%m-%dT%H:%M:%SZ; }
log() { echo "[$(timestamp)] $*" >> "$LOG_FILE"; }

# Ensure backup dir and log exist
mkdir -p "$BACKUP_DIR"
touch "$LOG_FILE"
chmod 700 "$BACKUP_DIR" || true

# Parse DB credentials from /etc/rd.conf [mySQL]
DBCONF="/etc/rd.conf"
if [[ ! -f "$DBCONF" ]]; then
    log "ERROR: $DBCONF not found; aborting backup"
    exit 1
fi

parse_key() {
    local key1="$1" key2="${2:-}"
    local val
    val=$(awk -F= '/^\[mySQL\]/{s=1;next}/^\[/{s=0} s&&/^'"$key1"'=/{print $2}' "$DBCONF" | tr -d ' \r' || true)
    if [[ -z "$val" && -n "$key2" ]]; then
        val=$(awk -F= '/^\[mySQL\]/{s=1;next}/^\[/{s=0} s&&/^'"$key2"'=/{print $2}' "$DBCONF" | tr -d ' \r' || true)
    fi
    echo "$val"
}

DB_NAME=$(parse_key Database)
DB_USER=$(parse_key Loginname DbUser)
DB_PASS=$(parse_key Password DbPassword)
DB_HOST=$(parse_key Hostname)
[[ -z "${DB_HOST}" ]] && DB_HOST=localhost

if [[ -z "$DB_NAME" || -z "$DB_USER" || -z "$DB_PASS" ]]; then
    log "ERROR: Missing DB credential(s): db='${DB_NAME:-}' user='${DB_USER:-}' pass_len=${#DB_PASS}"
    exit 1
fi

OUT_FILE="${BACKUP_DIR}/${BACKUP_PREFIX}_$(date +%Y_%m_%d).sql.gz"
TMP_SQL="${BACKUP_DIR}/.tmp_${BACKUP_PREFIX}_$$.sql"

log "Starting mysqldump for database '$DB_NAME'"
if mysqldump --protocol=socket -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" > "$TMP_SQL" 2>>"$LOG_FILE"; then
    gzip -c "$TMP_SQL" > "$OUT_FILE"
    rm -f "$TMP_SQL"
    log "Backup successful: $OUT_FILE"
else
    rc=$?
    rm -f "$TMP_SQL" || true
    log "ERROR: mysqldump failed with exit $rc"
    exit $rc
fi

# Prune old backups beyond retention
BACKUP_COUNT=$(find "$BACKUP_DIR" -maxdepth 1 -type f -name "${BACKUP_PREFIX}_*.sql.gz" | wc -l || echo 0)
if [[ "$BACKUP_COUNT" -gt "$BACKUP_RETENTION" ]]; then
    # delete oldest extras
    for f in $(find "$BACKUP_DIR" -maxdepth 1 -type f -name "${BACKUP_PREFIX}_*.sql.gz" | sort | head -n "$((BACKUP_COUNT-BACKUP_RETENTION))"); do
        rm -f "$f" && log "Deleted old backup: $f"
    done
else
    log "Retention OK: $BACKUP_COUNT backups present (<= $BACKUP_RETENTION)"
fi

log "Backup process completed"