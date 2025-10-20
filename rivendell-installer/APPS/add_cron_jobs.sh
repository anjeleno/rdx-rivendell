#!/bin/bash

# Add the cron job for daily_db_backup.sh
(crontab -l 2>/dev/null; echo "05 00 * * * /home/rd/imports/APPS/sql/daily_db_backup.sh") | crontab -
if [ $? -eq 0 ]; then
    echo "Cron job for daily_db_backup.sh added successfully."
else
    echo "Failed to add cron job for daily_db_backup.sh."
    exit 1
fi

# Add the cron job for autologgen.sh
(crontab -l 2>/dev/null; echo "15 00 * * * /home/rd/imports/APPS/autologgen.sh") | crontab -
if [ $? -eq 0 ]; then
    echo "Cron job for autologgen.sh added successfully."
else
    echo "Failed to add cron job for autologgen.sh."
    exit 1
fi

echo "All cron jobs added successfully."