#!/bin/bash

# Set PATH
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

# Configuration
BACKUP_RETENTION=14
BACKUP_DIR="/home/rd/imports/APPS/sql"
BACKUP_PREFIX="NIGHTLY_BACKUP"
LOG_FILE="${BACKUP_DIR}/cron_execution.log"

# Create backup
mysqldump -u rduser -p SQL_PASSWORD_GOES_HERE Rivendell | gzip > "${BACKUP_DIR}/${BACKUP_PREFIX}_$(date +%Y_%m_%d).sql.gz" 2>> "$LOG_FILE"

# Check if backup was successful
if [ $? -eq 0 ]; then
    echo "Backup successful: ${BACKUP_DIR}/${BACKUP_PREFIX}_$(date +%Y_%m_%d).sql.gz" >> "$LOG_FILE"
else
    echo "Backup failed!" >> "$LOG_FILE"
    exit 1
fi

# Count number of existing backups
BACKUP_COUNT=$(find "$BACKUP_DIR" -name "${BACKUP_PREFIX}_*.sql.gz" | wc -l)

# Delete oldest backup if we have more than retention limit
if [ "$BACKUP_COUNT" -gt "$BACKUP_RETENTION" ]; then
    OLDEST_BACKUP=$(find "$BACKUP_DIR" -name "${BACKUP_PREFIX}_*.sql.gz" | sort | head -n 1)
    if [ -n "$OLDEST_BACKUP" ]; then
        rm "$OLDEST_BACKUP"
        echo "Deleted oldest backup: $OLDEST_BACKUP" >> "$LOG_FILE"
    else
        echo "No old backup found to delete." >> "$LOG_FILE"
    fi
else
    echo "No need to delete old backups. Current count: $BACKUP_COUNT" >> "$LOG_FILE"
fi

echo "Backup process completed" >> "$LOG_FILE"