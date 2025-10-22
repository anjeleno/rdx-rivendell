#!/bin/bash
# RDX Permissions Fix Script - Run this if you get permission errors

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 RDX Broadcast Control Center - Permissions Fix${NC}"
echo "============================================================"

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}❌ Please do not run this script as root${NC}"
    echo "Run as a regular user with sudo privileges"
    exit 1
fi

# Check for sudo access
if ! sudo -n true 2>/dev/null; then
    echo -e "${BLUE}ℹ️  This script requires sudo privileges${NC}"
    sudo -v
fi

echo -e "${BLUE}ℹ️  Setting up broadcast management permissions...${NC}"

# Add sudo permissions for broadcast management
sudo tee /etc/sudoers.d/rdx-broadcast >/dev/null << 'EOSUDO'
# RDX Broadcast Control Center permissions
rd ALL=(root) NOPASSWD: /bin/cp /home/rd/.config/rdx/icecast.xml /etc/icecast2/icecast.xml
rd ALL=(root) NOPASSWD: /usr/bin/systemctl start icecast2
rd ALL=(root) NOPASSWD: /usr/bin/systemctl stop icecast2
rd ALL=(root) NOPASSWD: /usr/bin/systemctl restart icecast2
rd ALL=(root) NOPASSWD: /usr/bin/systemctl status icecast2
rd ALL=(root) NOPASSWD: /usr/bin/systemctl start liquidsoap
rd ALL=(root) NOPASSWD: /usr/bin/systemctl stop liquidsoap
rd ALL=(root) NOPASSWD: /usr/bin/systemctl restart liquidsoap
rd ALL=(root) NOPASSWD: /usr/bin/systemctl status liquidsoap
rd ALL=(root) NOPASSWD: /usr/bin/systemctl start jackd
rd ALL=(root) NOPASSWD: /usr/bin/systemctl stop jackd
rd ALL=(root) NOPASSWD: /usr/bin/systemctl restart jackd
rd ALL=(root) NOPASSWD: /usr/bin/systemctl status jackd
rd ALL=(root) NOPASSWD: /usr/sbin/service liquidsoap start
rd ALL=(root) NOPASSWD: /usr/sbin/service liquidsoap stop
rd ALL=(root) NOPASSWD: /usr/sbin/service liquidsoap restart
rd ALL=(root) NOPASSWD: /usr/sbin/service liquidsoap status
EOSUDO

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Broadcast management permissions configured${NC}"
else
    echo -e "${RED}❌ Failed to configure sudo permissions${NC}"
    exit 1
fi

# Fix ownership of rd user directories
echo -e "${BLUE}ℹ️  Fixing ownership of rd user directories...${NC}"
sudo chown -R rd:rd /home/rd/.config 2>/dev/null || true
sudo chown -R rd:rd /home/rd 2>/dev/null || true

echo -e "${GREEN}✅ Ownership fixed${NC}"

# Add rd user to audio groups
echo -e "${BLUE}ℹ️  Adding rd user to audio groups...${NC}"
sudo usermod -a -G audio,pulse-access rd 2>/dev/null || true

echo -e "${GREEN}✅ User groups updated${NC}"

echo ""
echo -e "${GREEN}🎉 Permissions setup complete!${NC}"
echo ""
echo -e "${BLUE}📱 You can now:${NC}"
echo "   • Apply Icecast configurations from the GUI"
echo "   • Control services (start/stop/restart)"
echo "   • Save configurations to system directories"
echo ""
echo -e "${YELLOW}💡 If you're still logged in as 'rd', you may need to:${NC}"
echo "   • Log out and log back in as 'rd' user"
echo "   • Or run: sudo su - rd"
echo ""