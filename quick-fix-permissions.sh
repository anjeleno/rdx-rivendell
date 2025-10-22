#!/bin/bash
# Quick Permissions Fix for RDX v3.0.6
# Run this to fix the current permission issues immediately

echo "🔧 RDX Quick Permission Fix"
echo "=============================="

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "❌ Please do not run this script as root"
    echo "Run as your regular user with sudo privileges"
    exit 1
fi

echo "ℹ️  Fixing sudo permissions for Icecast configuration..."

# Create specific sudo permissions for the exact path
sudo tee /etc/sudoers.d/rdx-broadcast >/dev/null << 'EOSUDO'
# RDX Broadcast Control Center permissions
rd ALL=(root) NOPASSWD: /bin/cp /home/rd/.config/rdx/icecast.xml /etc/icecast2/icecast.xml
rd ALL=(root) NOPASSWD: /usr/bin/systemctl start icecast2
rd ALL=(root) NOPASSWD: /usr/bin/systemctl stop icecast2
rd ALL=(root) NOPASSWD: /usr/bin/systemctl restart icecast2
rd ALL=(root) NOPASSWD: /usr/bin/systemctl status icecast2
EOSUDO

echo "✅ Sudo permissions configured"

echo "ℹ️  Fixing ownership of rd user directories..."
sudo chown -R rd:rd /home/rd/.config 2>/dev/null || true
sudo chown -R rd:rd /home/rd 2>/dev/null || true

echo "✅ Ownership fixed"

echo "ℹ️  Creating liquidsoap user service..."
sudo mkdir -p /home/rd/.config/systemd/user
sudo tee /home/rd/.config/systemd/user/liquidsoap.service >/dev/null << 'EOLIQ'
[Unit]
Description=Liquidsoap Daemon (User Service)
After=network.target sound.target
Wants=network.target

[Service]
Type=notify
User=rd
Group=rd
ExecStart=/usr/bin/liquidsoap /home/rd/.config/rdx/radio.liq
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=5
Environment=HOME=/home/rd
WorkingDirectory=/home/rd

[Install]
WantedBy=default.target
EOLIQ

sudo chown -R rd:rd /home/rd/.config/systemd 2>/dev/null || true

echo "✅ Liquidsoap user service configured"

echo ""
echo "🎉 Permissions fix complete!"
echo ""
echo "📱 You can now:"
echo "   • Apply Icecast configurations from the GUI"
echo "   • Save configurations without ownership issues"
echo "   • Control liquidsoap as user service"
echo ""
echo "💡 To enable liquidsoap user service (as rd user):"
echo "   sudo su - rd"
echo "   systemctl --user daemon-reload"
echo "   systemctl --user enable liquidsoap"
echo ""