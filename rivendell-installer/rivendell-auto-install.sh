#!/bin/bash
# Rivendell Auto-Install Script
# Version: 0.23.4
# Date: 2025-04-01
# Author: root@linuxconfigs.com
# Description: This script automates the installation and configuration of Rivendell,
#              MATE Desktop, xRDP, and related broadcasting tools optimized to run
#              on Ubuntu 22.04 on a cloud VPS. It includes everything you need
#              out-of-the-box to stream liquidsoap, icecast and audio processing.
#
#              Feel free to use my DigitalOcean referral link for a $200 redit to use
#              over 60 days and I'll get a little hookup too. :)
#              https://m.do.co/c/6fe3e9d36bc3
#
# Usage:       Run as your default user. Ensure you have sudo privileges.
#              After a reboot, rerun the script as the 'rd' user to resume installation.
#        
#              On first run, set your root password with sudo passwd root
#              Then cd Rivendell-Cloud ; chmod +x *.sh ; ./rivendell-auto-install.sh
#              Reboot when prompted
#              Login with: su rd (enter the password you set)
#              ./Rivendell-auto-install.sh
#              Enter the password you set for rd when prompted
#              Tasksel requires root to install MATE desktop. 
#              Enter your ROOT pw when prompted.

set -e  # Exit on error
# set -x  # Enable debugging

# Persistent step tracking directory
STEP_DIR="/home/rd/rivendell_install_steps"
INITIAL_STEPS_COMPLETED="/home/rd/initial_steps_completed"
TMP_STEP_DIR="/tmp/rivendell_install_steps"

# Ensure the step tracking directory exists and has the correct permissions
ensure_step_dir() {
    if [ ! -d "$STEP_DIR" ]; then
        sudo mkdir -p "$STEP_DIR"
        sudo chown rd:rd "$STEP_DIR"
    fi
}

# Ensure the temporary step tracking directory exists
ensure_tmp_step_dir() {
    if [ ! -d "$TMP_STEP_DIR" ]; then
        sudo mkdir -p "$TMP_STEP_DIR"
    fi
}

# Function to prompt user for confirmation
confirm() {
    read -p "$1 (y/n): " REPLY
    [[ $REPLY =~ ^[Yy]$ ]] || exit 1
}

# Function to check if a step has already been completed
step_completed() {
    local step_name="$1"
    if [ -f "$STEP_DIR/$step_name" ] || [ -f "$TMP_STEP_DIR/$step_name" ]; then
        echo "Step '$step_name' already completed. Skipping..."
        return 0
    else
        return 1
    fi
}

# Function to mark a step as completed
mark_step_completed() {
    local step_name="$1"
    if [ "$(whoami)" != "rd" ]; then
        touch "$TMP_STEP_DIR/$step_name"
    else
        touch "$STEP_DIR/$step_name"
    fi
}

# Function to ensure the script is running as the 'rd' user
ensure_rd_user() {
    if [ "$(whoami)" != "rd" ]; then
        echo "The script must be run as the 'rd' user. Please switch to the 'rd' user and rerun the script."
        echo "To switch to the 'rd' user, run:"
        echo "  su rd"
        echo "Then rerun the script."
        exit 1
    fi
}

# Ensure MySQL service is running
ensure_mysql_running() {
    if ! sudo systemctl is-active --quiet mariadb; then
        echo "Starting MySQL service..."
        sudo systemctl start mariadb
    fi
}

# Extract MySQL password and store it in a global variable
extract_mysql_password() {
    echo "Extracting MySQL password from /etc/rd.conf..."
    
    # Extract the MySQL password from the [mySQL] section of rd.conf
    MYSQL_PASSWORD=$(awk -F= '/\[mySQL\]/{flag=1;next}/\[/{flag=0}flag && /Password=/{print $2;exit}' /etc/rd.conf)
    
    # Check if the password was extracted successfully
    if [ -z "$MYSQL_PASSWORD" ]; then
        echo "Error: Failed to extract MySQL password from /etc/rd.conf. Please check the file and ensure the [mySQL] section exists."
        exit 1
    else
        echo "MySQL password extracted successfully: $MYSQL_PASSWORD"
    fi
    mark_step_completed "extract_mysql_password"
}

# Drop default tables and import custom SQL backup with advanced features in Rivendell db
import_sql_backup() {
    echo "Dropping all tables in database 'Rivendell' and importing SQL backup..."

    DB_HOST="localhost"
    DB_USER="rduser"
    DB_PASS="$MYSQL_PASSWORD"
    DB_NAME="Rivendell"
    BACKUP_FILE="/home/rd/imports/APPS/RDDB_v430_Cloud.sql"

    # Function to execute MariaDB commands
    execute_mariadb_command() {
        mariadb -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" "$@" 2>&1
    }

    # Drop all tables in the database
    echo "Dropping all tables in database '$DB_NAME'..."
    execute_mariadb_command -e "SET FOREIGN_KEY_CHECKS = 0; DROP TABLE IF EXISTS \`*\`; SET FOREIGN_KEY_CHECKS = 1;"

    # Import the SQL backup
    echo "Importing SQL backup from '$BACKUP_FILE'..."
    mariadb -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" < "$BACKUP_FILE" 2>&1

    # Check for errors during import
    if [ $? -ne 0 ]; then
        echo "Error importing SQL backup!"
        exit 1
    fi

    echo "SQL backup imported successfully!"
    mark_step_completed "import_sql_backup"
}

# Inject Rivendell SQL password in nightly SQL backup script
update_backup_script() {
    echo "Updating daily_db_backup.sh with MySQL password..."
    sed -i "s|SQL_PASSWORD_GOES_HERE|${MYSQL_PASSWORD}|" /home/rd/imports/APPS/sql/daily_db_backup.sh
    sed -i 's/ -p /-p/' /home/rd/imports/APPS/sql/daily_db_backup.sh
    echo "Backup script updated successfully."
    mark_step_completed "update_backup_script"
}

# Enable firewall and open ports for your WAN and/or LAN IP address(es)
enable_firewall() {
    echo "Configuring firewall..."
    sudo apt install -y ufw

    # Prompt user for external IP
    echo "Please enter your external IP address to allow in the firewall (leave blank if not applicable):"
    read -p "External IP: " EXTERNAL_IP

    # Prompt user for LAN subnet (e.g., 192.168.1.0/24) (leave blank if not applicable)
    echo "Please enter your LAN subnet (e.g., 192.168.1.0/24) (leave blank if not applicable):"
    read -p "LAN Subnet: " LAN_SUBNET

    # Apply firewall rules
    sudo ufw allow 8000/tcp
    sudo ufw allow ssh
    if [ -n "$EXTERNAL_IP" ]; then
        sudo ufw allow from "$EXTERNAL_IP"
    fi
    if [ -n "$LAN_SUBNET" ]; then
        sudo ufw allow from "$LAN_SUBNET"
    fi
    sudo ufw enable
    mark_step_completed "enable_firewall"
}

# Harden SSH access
harden_ssh() {
    echo "Hardening SSH access..."
    echo "WARNING: This will disable password authentication and allow only SSH key-based login."
    echo "Ensure you have added your SSH public key to ~/.ssh/authorized_keys and confirmed you can log in with it."
    confirm "Have you confirmed SSH key-based login works and want to proceed with hardening SSH?"

    # Backup SSH config files
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config-BAK
    sudo cp /etc/ssh/sshd_config.d/50-cloud-init.conf /etc/ssh/sshd_config.d/50-cloud-init.conf-BAK

    # Disable password authentication in sshd_config
    sudo sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/g' /etc/ssh/sshd_config
    sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config

    # Disable password authentication in 50-cloud-init.conf
    sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config.d/50-cloud-init.conf

    sudo systemctl restart ssh
    echo "SSH access has been hardened. Password authentication is now disabled."
    mark_step_completed "harden_ssh"
}

# Replace default icecast.xml with custom icecast.xml
configure_icecast() {
    echo "Configuring Icecast..."

    # Backup the original icecast.xml
    if [ -f /etc/icecast2/icecast.xml ]; then
        sudo cp /etc/icecast2/icecast.xml /etc/icecast2/icecast.xml.bak
        echo "Backed up original icecast.xml to /etc/icecast2/icecast.xml.bak"
    fi

    # Check if the custom icecast.xml exists
    if [ -f /home/rd/imports/APPS/icecast.xml ]; then
        sudo cp -f /home/rd/imports/APPS/icecast.xml /etc/icecast2/icecast.xml
        sudo chown root:icecast /etc/icecast2/icecast.xml
        sudo chmod 640 /etc/icecast2/icecast.xml
        echo "Custom icecast.xml copied successfully."
    else
        echo "Error: /home/rd/imports/APPS/icecast.xml does not exist. Please check the file path."
        exit 1
    fi

    echo "Icecast configuration updated."
    mark_step_completed "configure_icecast"
}

# Enable icecast server to start automatically
enable_icecast() {
    echo "Enabling and starting Icecast..."

    # Reload systemd and start Icecast
    sudo systemctl daemon-reload
    sudo systemctl enable icecast2
    sudo systemctl start icecast2

    echo "Icecast service enabled and started. Skipping status check to avoid blocking the script."
    mark_step_completed "enable_icecast"
}

# Disable PulseAudio and configure audio priorities
disable_pulseaudio() {
    echo "Disabling PulseAudio..."
    sudo killall pulseaudio || true
    sudo sed -i 's/# autospawn = yes/autospawn = no/' /etc/pulse/client.conf
    sudo gpasswd -d pulse audio || true
    sudo usermod -aG audio rd
    sudo usermod -aG audio rivendell
    sudo usermod -aG audio liquidsoap
    sudo tee -a /etc/security/limits.conf <<EOL
@audio      hard      rtprio          90
@audio      hard      memlock     unlimited
EOL
    mark_step_completed "disable_pulseaudio"
}

# Fix QT5 XCB error - fixes RD utilities that need root in xRDP enviornment
fix_qt5() {
    echo "Fixing QT5 XCB error..."
    sudo ln -s /home/rd/.Xauthority /root/.Xauthority
    mark_step_completed "fix_qt5"
}

# Restore original .bashrc for rd user after final step
restore_bashrc() {
    echo "Restoring original .bashrc for rd user..."
    if [ -f /home/rd/.bashrc.bak ]; then
        sudo mv /home/rd/.bashrc.bak /home/rd/.bashrc
        sudo chown rd:rd /home/rd/.bashrc
        echo "Original .bashrc restored."
    else
        echo "Backup .bashrc not found. Skipping restore."
    fi
    mark_step_completed "restore_bashrc"
}

# Update and upgrade the system
system_update() {
    echo "Updating system..."
    while sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
        echo "Waiting for other apt processes to finish..."
        sleep 5
    done
    sudo apt update && sudo apt dist-upgrade -y
    if [ $? -eq 0 ]; then
        echo "System update completed successfully."
    else
        echo "System update failed."
        exit 1
    fi
    mark_step_completed "system_update"
}

# Set hostname to match custom Rivendell server config
set_hostname() {
    echo "Setting hostname..."
    sudo hostnamectl set-hostname onair
    sudo sed -i "/127.0.1.1/c\127.0.1.1\tonair" /etc/hosts
    mark_step_completed "set_hostname"
}

# Set timezone
set_timezone() {
    echo "Setting timezone..."
    echo "Please select your timezone:"
    sudo dpkg-reconfigure tzdata
    sudo timedatectl set-ntp yes
    mark_step_completed "set_timezone"
}

# Create 'rd' user and add to sudo group
create_rd_user() {
    echo "Creating 'rd' user..."
    if ! id -u rd >/dev/null 2>&1; then
        sudo adduser --disabled-password --gecos "rd,Rivendell Audio,,," --home /home/rd rd
        sudo usermod -aG sudo rd
        echo "Please set a password for the 'rd' user:"
        sudo passwd rd
        sudo chown -R rd:rd /home/rd
        sudo chmod 755 /home/rd
        echo "User 'rd' created. Skeleton files copied to /home/rd."
    else
        echo "User 'rd' already exists. Skipping..."
    fi
    mark_step_completed "create_rd_user"
}

# Setup tmp directories for Rivendell auto-install in 'rd' user account
copy_working_directory() {
    echo "Copying working directory to /home/rd/Rivendell-Cloud..."
    if [ ! -d "/home/rd/Rivendell-Cloud" ]; then
        sudo cp -r "$(pwd)" /home/rd/Rivendell-Cloud
        sudo chown -R rd:rd /home/rd/Rivendell-Cloud
        echo "Working directory copied successfully."
    else
        echo "Working directory already exists. Skipping copy."
    fi
    mark_step_completed "copy_working_directory"
}

# Backup virgin .bashrc file for recovery after final installation step
backup_bashrc() {
    echo "Backing up original .bashrc..."
    if [ -f /home/rd/.bashrc ]; then
        sudo cp /home/rd/.bashrc /home/rd/.bashrc.bak
        sudo chown rd:rd /home/rd/.bashrc.bak
        echo "Original .bashrc backed up to .bashrc.bak"
    fi
    mark_step_completed "backup_bashrc"
}

# Redirect shell to working directory during install requiring su rd
configure_shell_profile() {
    echo "Configuring shell profile to auto-change directory on login..."
    if ! grep -q "cd /home/rd/Rivendell-Cloud" /home/rd/.bashrc; then
        echo "cd /home/rd/Rivendell-Cloud" | sudo tee -a /home/rd/.bashrc > /dev/null
        sudo chown rd:rd /home/rd/.bashrc
        echo "Shell profile configured."
    else
        echo "Shell profile already configured. Skipping."
    fi
    mark_step_completed "configure_shell_profile"
}

# Reboots system to apply Linux kernel updates and new hostname
prompt_reboot() {
    echo "Reboot is required to apply kernel updates and new hostname. Do you want to reboot now? (y/n)"
    read -r answer
    if [ "$answer" != "${answer#[Yy]}" ]; then
        sudo reboot
    else
        echo "Please reboot the system manually to continue."
    fi
}

# Install tasksel if not already installed
install_tasksel() {
    echo "Installing tasksel..."
    sudo apt install tasksel -y
    mark_step_completed "install_tasksel"
}

# Install MATE Desktop using tasksel as root
install_mate() {
    echo "Installing MATE Desktop..."
    echo "MATE Desktop installing as root. Enter ROOT password below. Then, use the arrow keys and spacebar to select MATE, OK and enter to continue."
    su -c "tasksel"
    mark_step_completed "install_mate"
}

# Install xRDP
install_xrdp() {
    echo "Installing xRDP..."
    sudo apt install xrdp dbus-x11 -y
    mark_step_completed "install_xrdp"
}

# Configure xRDP to use MATE
configure_xrdp() {
    echo "Configuring xRDP to use MATE..."
    echo "mate-session" | sudo tee /home/rd/.xsession > /dev/null
    sudo chown rd:rd /home/rd/.xsession  # Ensure rd owns the file
    sudo systemctl restart xrdp
    mark_step_completed "configure_xrdp"
}

# Set MATE as the default session manager
set_mate_default() {
    echo "Setting MATE as the default session manager..."
    sudo update-alternatives --config x-session-manager <<< '2'  # Select MATE
    sudo update-alternatives --config x-session-manager <<< '0'  # Set to auto mode
    mark_step_completed "set_mate_default"
}

# Global variable to track the installation type
INSTALL_TYPE=""

# Function to determine Ubuntu version and invoke the correct Rivendell installer
install_rivendell() {
    # Get the Ubuntu version
    UBUNTU_VERSION=$(lsb_release -rs)

    echo "Detected Ubuntu version: $UBUNTU_VERSION"

    if [[ "$UBUNTU_VERSION" == "22.04" ]]; then
        echo "Installing Rivendell for Ubuntu 22.04 Jammy..."
        wget https://software.paravelsystems.com/ubuntu/dists/jammy/main/install_rivendell.sh || return 1
        chmod +x install_rivendell.sh || return 1
        echo "Please choose the installation type:"
        echo "1) Standalone"
        echo "2) Server"
        echo "3) Client"
        read -p "Enter the number of your choice: " choice
        INSTALL_TYPE="$choice"
        sudo ./install_rivendell.sh <<< "$choice" || return 1
        mark_step_completed "install_rivendell"
    elif [[ "$UBUNTU_VERSION" == "24.04" ]]; then
        echo "Installing Rivendell for Ubuntu 24.04 Noble..."
        wget https://software.paravelsystems.com/ubuntu/dists/noble/main/install_rivendell.sh || return 1
        chmod +x install_rivendell.sh || return 1
        echo "Please choose the installation type:"
        echo "1) Standalone"
        echo "2) Server"
        echo "3) Client"
        read -p "Enter the number of your choice: " choice
        INSTALL_TYPE="$choice"
        sudo ./install_rivendell.sh <<< "$choice" || return 1
        mark_step_completed "install_rivendell"
    else
        echo "Unsupported Ubuntu version: $UBUNTU_VERSION"
        echo "This script only supports Ubuntu 22.04 (Jammy) and Ubuntu 24.04 (Noble)."
        exit 1
    fi
}

# Create pypad text file to optionally send RD now and next meta to web, RDS, or external app
touch_pypad() {
    echo "Creating /var/www/html/meta.txt..."

    # Ensure the directory exists
    if [ ! -d /var/www/html ]; then
        sudo mkdir -p /var/www/html
    fi

    # Create the meta.txt file
    sudo touch /var/www/html/meta.txt

    # Change ownership of the meta.txt file
    sudo chown pypad:pypad /var/www/html/meta.txt

    if [ -f /var/www/html/meta.txt ]; then
        echo "meta.txt created and ownership set to pypad:pypad successfully."
    else
        echo "Failed to create meta.txt."
        exit 1
    fi

    mark_step_completed "touch_pypad"
}

# Install broadcasting tools (Icecast, JACK, Liquidsoap, VLC) for streaming and capturing LIVE Remote audio
install_broadcasting_tools() {
    echo "Installing broadcasting tools..."
    sudo apt install -y icecast2 jackd2 qjackctl liquidsoap vlc vlc-plugin-jack
    mark_step_completed "install_broadcasting_tools"
}

# Create directories as 'rd' user
create_directories() {
    echo "Creating directories..."
    mkdir -p /home/rd/imports /home/rd/logs
    chown rd:rd /home/rd/imports /home/rd/logs
    mark_step_completed "create_directories"
}

# Move APPS folder and set permissions as 'rd' user
move_apps() {
    echo "Moving APPS folder and setting permissions..."
    APPS_SRC="/home/rd/Rivendell-Cloud/APPS"
    APPS_DEST="/home/rd/imports/APPS"
    mv "$APPS_SRC" "$APPS_DEST"
    chmod -R +x "$APPS_DEST"
    chown -R rd:rd "$APPS_DEST"
    mark_step_completed "move_apps"
}

# Move desktop shortcuts as 'rd' user
move_shortcuts() {
    echo "Moving desktop shortcuts..."
    SHORTCUTS_SRC="/home/rd/imports/APPS/Shortcuts"
    USER_DESKTOP="/home/rd/Desktop"

    # Ensure the Desktop directory exists
    mkdir -p "$USER_DESKTOP"

    if [ -d "$SHORTCUTS_SRC" ]; then
        mv "$SHORTCUTS_SRC"/* "$USER_DESKTOP" || {
            echo "Failed to move desktop shortcuts. Check permissions or if files already exist."
            exit 1
        }
        echo "Desktop shortcuts moved successfully."
    else
        echo "Error: $SHORTCUTS_SRC does not exist. Check if the APPS folder was downloaded correctly."
        exit 1
    fi
    mark_step_completed "move_shortcuts"
}

# Move custom configs to make persistent Jack connections, streaming and LIVE remote magic happen
move_custom_configs() {
    echo "Moving custom configs..."
    mkdir -p /home/rd/.config/vlc
    mkdir -p /home/rd/.config/rncbc.org

    if [ -f /home/rd/imports/APPS/configs/vlc-qt-interface.conf ]; then
        mv /home/rd/imports/APPS/configs/vlc-qt-interface.conf /home/rd/.config/vlc/vlc-qt-interface.conf
        if [ $? -eq 0 ]; then
            echo "Moved vlc-qt-interface.conf successfully"
        else
            echo "Failed to move vlc-qt-interface.conf"
        fi
    else
        echo "vlc-qt-interface.conf not found"
    fi

    if [ -f /home/rd/imports/APPS/configs/vlcrc ]; then
        mv /home/rd/imports/APPS/configs/vlcrc /home/rd/.config/vlc/vlcrc
        if [ $? -eq 0 ]; then
            echo "Moved vlcrc successfully"
        else
            echo "Failed to move vlcrc"
        fi
    else
        echo "vlcrc not found"
    fi

    if [ -f /home/rd/imports/APPS/configs/QjackCtl.conf ]; then
        mv /home/rd/imports/APPS/configs/QjackCtl.conf /home/rd/.config/rncbc.org/QjackCtl.conf
        if [ $? -eq 0 ]; then
            echo "Moved QjackCtl.conf successfully"
        else
            echo "Failed to move QjackCtl.conf"
        fi
    else
        echo "QjackCtl.conf not found"
    fi

    if [ -f /home/rd/imports/APPS/configs/.stereo_tool_gui_jack_64_1030.rc ]; then
        mv /home/rd/imports/APPS/configs/.stereo_tool_gui_jack_64_1030.rc /home/rd/.stereo_tool_gui_jack_64_1030.rc
        if [ $? -eq 0 ]; then
            echo "Moved .stereo_tool_gui_jack_64_1030.rc successfully"
        else
            echo "Failed to move .stereo_tool_gui_jack_64_1030.rc"
        fi
    else
        echo ".stereo_tool_gui_jack_64_1030.rc not found"
    fi

    chown -R rd:rd /home/rd/.config/vlc
    chown -R rd:rd /home/rd/.config/rncbc.org
    chown rd:rd /home/rd/.stereo_tool_gui_jack_64_1030.rc

    echo "Custom configs moved successfully."
    mark_step_completed "move_custom_configs"
}

fix_pypad_syntax() {
    # Check if the system is running Ubuntu 24.04, if so, fix pypad syntax. 
    UBUNTU_VERSION=$(lsb_release -rs)
    if [[ "$UBUNTU_VERSION" == "24.04" ]]; then
        echo "Detected Ubuntu 24.04. Checking and fixing Python syntax in pypad.py..."

        # Path to the pypad.py file
        PYTHON_FILE="/usr/lib/python3/dist-packages/rivendellaudio/pypad.py"

        # Check if the file exists
        if [ -f "$PYTHON_FILE" ]; then
            # Replace the deprecated config.readfp() with config.read()
            sudo sed -i "s/config\.readfp(open('\/etc\/rd\.conf'))/config.read('\/etc\/rd\.conf')/" "$PYTHON_FILE"

            # Verify the change
            if grep -q "config.read('/etc/rd.conf')" "$PYTHON_FILE"; then
                echo "Python syntax in pypad.py fixed successfully."
            else
                echo "Failed to fix Python syntax in pypad.py. Please check the file manually."
            fi
        else
            echo "File $PYTHON_FILE not found. Skipping fix."
        fi
    else
        echo "Not running Ubuntu 24.04. Skipping pypad.py fix."
    fi
}

# Main script execution
if [ "$(whoami)" != "rd" ]; then
    # First run as root or default user
    TMP_STEP_DIR="/tmp/rivendell_install_steps"
    mkdir -p "$TMP_STEP_DIR"

    system_update
    set_hostname
    create_rd_user
    copy_working_directory
    backup_bashrc
    configure_shell_profile
    touch "$INITIAL_STEPS_COMPLETED"
    sudo chown rd:rd "$INITIAL_STEPS_COMPLETED"
    prompt_reboot
    exit 1
fi

# After reboot, running as rd user
ensure_rd_user

# Ensure the step directory exists
ensure_step_dir

# Always start from setting the timezone after reboot
if ! step_completed "set_timezone"; then set_timezone; fi

# Before Rivendell installation
echo "Executing pre-Rivendell installation steps..."
if ! step_completed "install_tasksel"; then install_tasksel; fi
if ! step_completed "install_mate"; then install_mate; fi
if ! step_completed "install_xrdp"; then install_xrdp; fi
if ! step_completed "configure_xrdp"; then configure_xrdp; fi
if ! step_completed "set_mate_default"; then set_mate_default; fi

# Rivendell installation
if ! step_completed "install_rivendell"; then install_rivendell; fi

# After Rivendell installation
if [[ "$INSTALL_TYPE" == "3" ]]; then
    echo "Client installation selected. Only executing client-specific steps..."
    if ! step_completed "disable_pulseaudio"; then disable_pulseaudio; fi
    if ! step_completed "fix_qt5"; then fix_qt5; fi
    if ! step_completed "enable_firewall"; then enable_firewall; fi
    if ! step_completed "harden_ssh"; then harden_ssh; fi
    if ! step_completed "restore_bashrc"; then restore_bashrc; fi
else
    echo "Standalone or Server installation selected. Executing all steps..."
    if ! step_completed "touch_pypad"; then touch_pypad; fi
    if ! step_completed "install_broadcasting_tools"; then install_broadcasting_tools; fi
    if ! step_completed "create_directories"; then create_directories; fi
    if ! step_completed "move_apps"; then move_apps; fi
    if ! step_completed "move_shortcuts"; then move_shortcuts; fi
    if ! step_completed "move_custom_configs"; then move_custom_configs; fi
    if ! step_completed "configure_icecast"; then configure_icecast; fi
    if ! step_completed "enable_icecast"; then enable_icecast; fi
    if ! step_completed "disable_pulseaudio"; then disable_pulseaudio; fi
    if ! step_completed "fix_qt5"; then fix_qt5; fi
    if ! step_completed "extract_mysql_password"; then extract_mysql_password; fi
    if ! step_completed "update_backup_script"; then update_backup_script; fi
    if ! step_completed "import_sql_backup"; then import_sql_backup; fi

    # Fix Python syntax in pypad.py for Ubuntu 24.04
    if ! step_completed "fix_pypad_syntax"; then fix_pypad_syntax; fi

    if ! step_completed "enable_firewall"; then enable_firewall; fi
    if ! step_completed "harden_ssh"; then harden_ssh; fi
    if ! step_completed "restore_bashrc"; then restore_bashrc; fi
fi

# Housekeeping
housekeeping() {
    echo "Cleaning up tmp files"
    rm -rf /home/rd/Rivendell-Cloud
    rm -rf /home/rd/rivendell_install_steps
}

# Prompt user to reboot
final_reboot() {
    confirm "Would you like to reboot now to apply changes?"

    echo "Rebooting system..."
    sudo reboot
}

if ! step_completed "final_reboot"; then final_reboot; fi