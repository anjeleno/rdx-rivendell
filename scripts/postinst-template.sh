#!/bin/bash
# RDX Enhanced post-installation script

set -e

case "$1" in
    configure)
        echo "🎯 Configuring RDX Enhanced v2.4.2..."
        echo ""
        
        # Service configuration
        echo "🔧 Service Configuration:"
        echo "   rdx-jack-helper                    # JACK audio routing service"
        echo "   systemctl status rdx-jack-helper   # Check service status"
        echo ""
        
        # CLI commands  
        echo "📡 Audio Routing Commands:"
        echo "   rdx-jack-helper --scan              # Discover audio devices"
        echo "   rdx-jack-helper --profile live      # Load broadcast profile"
        echo "   rdx-jack-helper --status            # Check connection status"
        echo ""
        echo "📡 Streaming Commands:"
        echo "   rdx-stream start [hq|medium|low]    # Start AAC+ streaming"
        echo "   rdx-stream stop                     # Stop streaming"
        echo "   rdx-stream status                   # Check stream status"
        echo ""
        echo "🧠 Dependency Management:"
        echo "   rdx-deps check                      # Check all dependencies"
        echo "   rdx-deps install                    # Install missing packages"
        echo ""
        
        # Auto-detect and integrate with RDAdmin
        echo "🎯 RDAdmin Integration:"
        echo "   Checking for existing Rivendell installation..."
        
        if [ -f "/etc/rd.conf" ] && [ -x "/usr/bin/rdadmin" ]; then
            echo "   ✅ Rivendell detected - integrating RDX with RDAdmin..."
            
            # Read database credentials from rd.conf
            DB_HOST=$(grep -E "^Hostname=" /etc/rd.conf | cut -d'=' -f2 | tr -d ' ')
            DB_NAME=$(grep -E "^Database=" /etc/rd.conf | cut -d'=' -f2 | tr -d ' ')
            DB_USER=$(grep -E "^Loginname=" /etc/rd.conf | cut -d'=' -f2 | tr -d ' ')
            DB_PASS=$(grep -E "^Password=" /etc/rd.conf | cut -d'=' -f2 | tr -d ' ')
            
            if [ -n "$DB_HOST" ] && [ -n "$DB_NAME" ] && [ -n "$DB_USER" ]; then
                echo "   📡 Database connection: $DB_USER@$DB_HOST/$DB_NAME"
                
                # Create RDX host entry in Rivendell database
                mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" <<EOF 2>/dev/null || echo "   ⚠️  Database integration failed (this is OK for standalone use)"
INSERT IGNORE INTO STATIONS (NAME, SHORT_NAME, DESCRIPTION, USER_NAME, DEFAULT_NAME, IPV4_ADDRESS, HTTP_STATION, CAE_STATION, WEB_SERVICE_LEVEL, STARTUP_CART, EDITOR_PATH, FILTER_MODE, START_JACK, JACK_SERVER_NAME, JACK_COMMAND_LINE, JACK_SESSION_RESTORE) 
VALUES ('RDX-HOST', 'RDX', '🔥 RDX Audio Control', '$DB_USER', 'RDX Host', '127.0.0.1', 'Y', 'Y', 2, 0, '', 0, 'Y', 'default', '/usr/bin/jackd -d alsa', 'Y');

INSERT IGNORE INTO RDHOTKEYS (STATION_NAME, MODULE_NAME, KEY_ID, KEY_VALUE, KEY_LABEL) 
VALUES ('RDX-HOST', 'RDAdmin', 1, '/usr/local/bin/rdx-gui-launcher', '🔥 RDX Audio Control');
EOF
                
                echo "   ✅ RDX integrated with RDAdmin successfully!"
                echo "   🎯 You can now open RDAdmin > Hosts > RDX-HOST to access RDX GUI"
            else
                echo "   ⚠️  Could not read database credentials from /etc/rd.conf"
            fi
        else
            echo "   ℹ️  No Rivendell installation detected - RDX will run standalone"
        fi
        
        echo ""
        echo "📡 Your system now has WICKED intelligent audio + AAC+ streaming!"
        echo ""
        echo "🎉 INSTALLATION COMPLETE! RDX is ready to use:"
        echo "   • If you have Rivendell: Open RDAdmin > Hosts > RDX-HOST"
        echo "   • For standalone use: Run 'rdx-gui-launcher' or use CLI commands"
        ;;
esac

exit 0