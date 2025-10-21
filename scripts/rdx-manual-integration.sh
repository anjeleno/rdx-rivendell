#!/bin/bash
# RDX Manual RDAdmin Integration Script
# Safely adds RDX to RDAdmin Hosts menu

echo "🔥 RDX RDAdmin Integration Script"
echo "================================="
echo ""

# Check if Rivendell is installed
echo "1. 🔍 Checking Rivendell installation..."
if [ ! -f "/etc/rd.conf" ]; then
    echo "   ❌ /etc/rd.conf not found. Rivendell not installed."
    exit 1
fi

if [ ! -x "/usr/bin/rdadmin" ]; then
    echo "   ❌ rdadmin not found. Rivendell not properly installed."
    exit 1
fi

echo "   ✅ Rivendell installation detected"
echo ""

# Read database credentials
echo "2. 🔍 Reading database credentials..."
DB_HOST=$(grep -E "^Hostname=" /etc/rd.conf | cut -d'=' -f2 | tr -d ' ')
DB_NAME=$(grep -E "^Database=" /etc/rd.conf | cut -d'=' -f2 | tr -d ' ')
DB_USER=$(grep -E "^Loginname=" /etc/rd.conf | cut -d'=' -f2 | tr -d ' ')
DB_PASS=$(grep -E "^Password=" /etc/rd.conf | cut -d'=' -f2 | tr -d ' ')

if [ -z "$DB_HOST" ] || [ -z "$DB_NAME" ] || [ -z "$DB_USER" ]; then
    echo "   ❌ Could not read database credentials from /etc/rd.conf"
    exit 1
fi

echo "   ✅ Database credentials found: $DB_USER@$DB_HOST/$DB_NAME"
echo ""

# Test database connection
echo "3. 🔍 Testing database connection..."
if ! mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SELECT 1;" >/dev/null 2>&1; then
    echo "   ❌ Database connection failed"
    exit 1
fi

echo "   ✅ Database connection successful"
echo ""

# Check if RDX-HOST already exists
echo "4. 🔍 Checking for existing RDX integration..."
EXISTING_STATION=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SELECT NAME FROM STATIONS WHERE NAME='RDX-HOST';" 2>/dev/null | grep -v NAME | head -1)

if [ -n "$EXISTING_STATION" ]; then
    echo "   ⚠️  RDX-HOST already exists in database. Updating..."
    
    # Update existing entry (without emoji to avoid encoding issues)
    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" <<EOF
UPDATE STATIONS SET 
    SHORT_NAME='RDX',
    DESCRIPTION='RDX Audio Control',
    USER_NAME='$DB_USER',
    DEFAULT_NAME='RDX Host',
    IPV4_ADDRESS='127.0.0.1',
    HTTP_STATION='Y',
    CAE_STATION='Y',
    WEB_SERVICE_LEVEL=2,
    STARTUP_CART=0,
    EDITOR_PATH='',
    FILTER_MODE=0,
    START_JACK='Y',
    JACK_SERVER_NAME='default',
    JACK_COMMAND_LINE='/usr/bin/jackd -d alsa',
    JACK_SESSION_RESTORE='Y'
WHERE NAME='RDX-HOST';
EOF
    
    if [ $? -eq 0 ]; then
        echo "   ✅ RDX-HOST entry updated successfully"
    else
        echo "   ❌ Failed to update RDX-HOST entry"
        exit 1
    fi
else
    echo "   ℹ️  RDX-HOST not found. Creating new entry..."
    
    # Create new entry (without emoji to avoid encoding issues) 
    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" <<EOF
INSERT INTO STATIONS (
    NAME, SHORT_NAME, DESCRIPTION, USER_NAME, DEFAULT_NAME, 
    IPV4_ADDRESS, HTTP_STATION, CAE_STATION, WEB_SERVICE_LEVEL, 
    STARTUP_CART, EDITOR_PATH, FILTER_MODE, START_JACK, 
    JACK_SERVER_NAME, JACK_COMMAND_LINE, JACK_SESSION_RESTORE
) VALUES (
    'RDX-HOST', 'RDX', 'RDX Audio Control', '$DB_USER', 'RDX Host',
    '127.0.0.1', 'Y', 'Y', 2, 0, '', 0, 'Y', 
    'default', '/usr/bin/jackd -d alsa', 'Y'
);
EOF
    
    if [ $? -eq 0 ]; then
        echo "   ✅ RDX-HOST entry created successfully"
    else
        echo "   ❌ Failed to create RDX-HOST entry"
        exit 1
    fi
fi

echo ""
echo "🎉 SUCCESS! RDX integration complete!"
echo ""
echo "📋 Next Steps:"
echo "   1. Open RDAdmin"
echo "   2. Click 'Manage Hosts'"
echo "   3. Look for 'RDX-HOST' in the list"
echo "   4. Double-click 'RDX-HOST' to configure it"
echo ""
echo "🎯 The RDX-HOST entry is now available in RDAdmin's host management."
echo "   You can use it to launch RDX GUI or configure RDX settings."