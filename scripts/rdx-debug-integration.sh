#!/bin/bash
# RDX RDAdmin Integration Diagnostic Script
# This script diagnoses why RDX isn't appearing in RDAdmin hosts menu

echo "🔍 RDX RDAdmin Integration Diagnostic"
echo "======================================"
echo ""

# Check if Rivendell is installed
echo "1. 🔍 Rivendell Installation Check:"
if [ -f "/etc/rd.conf" ]; then
    echo "   ✅ /etc/rd.conf found"
else
    echo "   ❌ /etc/rd.conf not found"
    exit 1
fi

if [ -x "/usr/bin/rdadmin" ]; then
    echo "   ✅ rdadmin executable found"
else
    echo "   ❌ rdadmin not found"
    exit 1
fi

echo ""

# Check database credentials
echo "2. 🔍 Database Credentials Check:"
DB_HOST=$(grep -E "^Hostname=" /etc/rd.conf | cut -d'=' -f2 | tr -d ' ')
DB_NAME=$(grep -E "^Database=" /etc/rd.conf | cut -d'=' -f2 | tr -d ' ')
DB_USER=$(grep -E "^Loginname=" /etc/rd.conf | cut -d'=' -f2 | tr -d ' ')
DB_PASS=$(grep -E "^Password=" /etc/rd.conf | cut -d'=' -f2 | tr -d ' ')

echo "   Host: ${DB_HOST:-[NOT FOUND]}"
echo "   Database: ${DB_NAME:-[NOT FOUND]}"
echo "   Username: ${DB_USER:-[NOT FOUND]}"
echo "   Password: ${DB_PASS:+[FOUND]}${DB_PASS:-[NOT FOUND]}"

if [ -z "$DB_HOST" ] || [ -z "$DB_NAME" ] || [ -z "$DB_USER" ]; then
    echo "   ❌ Missing database credentials"
    exit 1
fi

echo ""

# Test database connection
echo "3. 🔍 Database Connection Test:"
if mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SELECT 1;" >/dev/null 2>&1; then
    echo "   ✅ Database connection successful"
else
    echo "   ❌ Database connection failed"
    exit 1
fi

echo ""

# Check table structures
echo "4. 🔍 Database Table Structure Check:"
echo "   Checking STATIONS table..."
mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "DESCRIBE STATIONS;" 2>/dev/null | grep -E "(NAME|SHORT_NAME|DESCRIPTION)" || echo "   ⚠️  STATIONS table structure different than expected"

echo "   Checking RDHOTKEYS table..."
mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "DESCRIBE RDHOTKEYS;" 2>/dev/null | grep -E "(STATION_NAME|MODULE_NAME|KEY_ID)" || echo "   ⚠️  RDHOTKEYS table structure different than expected"

echo ""

# Check if RDX-HOST already exists
echo "5. 🔍 Existing RDX Integration Check:"
EXISTING_STATION=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SELECT NAME FROM STATIONS WHERE NAME='RDX-HOST';" 2>/dev/null | grep -v NAME | head -1)
if [ -n "$EXISTING_STATION" ]; then
    echo "   ✅ RDX-HOST station found in database"
else
    echo "   ❌ RDX-HOST station not found in database"
fi

EXISTING_HOTKEY=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SELECT STATION_NAME FROM RDHOTKEYS WHERE STATION_NAME='RDX-HOST' AND MODULE_NAME='RDAdmin';" 2>/dev/null | grep -v STATION_NAME | head -1)
if [ -n "$EXISTING_HOTKEY" ]; then
    echo "   ✅ RDX hotkey found in database"
else
    echo "   ❌ RDX hotkey not found in database"
fi

echo ""

# List all stations for reference
echo "6. 🔍 All Stations in Database:"
mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SELECT NAME, SHORT_NAME, DESCRIPTION FROM STATIONS ORDER BY NAME;" 2>/dev/null || echo "   ❌ Could not list stations"

echo ""
echo "🎯 Diagnostic complete. Use this information to troubleshoot the integration."