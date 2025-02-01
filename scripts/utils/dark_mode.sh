#!/bin/bash

# NAFO Radio - Dark Mode Enabler
# Because even our UI needs OPSEC

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Function to get sudo privileges
get_sudo() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${YELLOW}This script requires administrative privileges.${NC}"
        sudo -v || exit 1
    fi
}

# Main function
main() {
    echo -e "${YELLOW}NAFO Radio Dark Mode Utility${NC}"
    
    # Get sudo privileges
    get_sudo
    
    # Get current user's home directory
    USER_HOME="/home/$SUDO_USER"
    
    echo "Installing Arc-Dark theme..."
    sudo apt update
    sudo apt install -y arc-theme
    
    echo "Applying dark theme for $SUDO_USER..."
    
    # Create user config directories if they don't exist
    sudo -u "$SUDO_USER" mkdir -p "$USER_HOME/.config/gtk-3.0"
    sudo -u "$SUDO_USER" mkdir -p "$USER_HOME/.config/lxsession/LXDE-pi"
    sudo -u "$SUDO_USER" mkdir -p "$USER_HOME/.config/lxterminal"
    
    # Apply GTK3 settings for user
    sudo -u "$SUDO_USER" tee "$USER_HOME/.config/gtk-3.0/settings.ini" > /dev/null << EOF
[Settings]
gtk-theme-name=Arc-Dark
gtk-application-prefer-dark-theme=1
EOF
    
    # Apply LXDE settings for user
    sudo -u "$SUDO_USER" tee "$USER_HOME/.config/lxsession/LXDE-pi/desktop.conf" > /dev/null << EOF
[GTK]
gtk-theme-name=Arc-Dark
EOF
    
    # Apply terminal settings for user
    sudo -u "$SUDO_USER" tee "$USER_HOME/.config/lxterminal/lxterminal.conf" > /dev/null << EOF
[general]
bgcolor=#000000
fgcolor=#ffffff
EOF
    
    # Set correct ownership
    sudo chown -R "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.config"
    
    echo "Restarting UI components..."
    sudo -u "$SUDO_USER" lxpanelctl restart
    
    echo -e "${GREEN}Dark Mode enabled for user $SUDO_USER!${NC}"
    echo -e "${YELLOW}Please log out and log back in for all changes to take effect.${NC}"
}

# Run main process
main 