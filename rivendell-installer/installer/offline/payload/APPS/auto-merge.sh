#!/bin/bash
export DISPLAY=:0.0
date >/home/rd/advanceLogGeneration.log
$hostname >>/home/rd/advanceLogGeneration.log
#make log for Production
/usr/bin/rdlogmanager -P -d 1 -t -s Production
 >>/home/rd/advanceLogGeneration.log

#clean up log perms and put in one place
chown rd:rd /home/rd/*.log

exit 0


# EXAMPLE: /usr/bin/rdlogmanager -P -g -d 1 -m -t -s Production

# rdlogmanager --help

# rdlogmanager [-P] [-g] [-m] [-t] [-r <rpt-name>] [-d <days>] [-e <days>]
# -s <svc-name>

# -P
#     Do not overwrite existing logs or imports.

# -g
#     Generate a new log for the specified service.

# -m
#     Merge the Music log for the specified service.

# -t
#     Merge the Traffic log for the specified service.

# -r <rpt-name>
#     Generate report <rpt-name>.

# -d <days>
#    Specify a start date offset.  For log operations, this will be added
#     to tomorrow's date to arrive at a target date, whereas for report
#     operations it will be added to yesterday's date to arrive at a target
#     date.  Default value is '0'.

# -e <days>
#     Specify an end date offset.  This will be added to yesterday's date
#     to arrive at a target end date.  Valid only for certain report types.
#     Default value is '0'.

# -s <service-name>
#     Specify service <service-name> for log operations.
