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
    
    echo "Installing Arc-Dark theme..."
    sudo apt update
    sudo apt install -y arc-theme
    
    echo "Applying dark theme..."
    sudo mkdir -p /home/$SUDO_USER/.config/gtk-3.0
    sudo bash -c "echo -e '[Settings]\ngtk-application-prefer-dark-theme=1' > /home/$SUDO_USER/.config/gtk-3.0/settings.ini"
    sudo chown -R $SUDO_USER:$SUDO_USER /home/$SUDO_USER/.config/gtk-3.0
    
    echo "Configuring LXDE to use dark mode..."
    sudo mkdir -p /home/$SUDO_USER/.config/lxsession/LXDE-pi
    sudo bash -c "echo -e '[GTK]\ngtk-theme-name=Arc-Dark' > /home/$SUDO_USER/.config/lxsession/LXDE-pi/desktop.conf"
    sudo chown -R $SUDO_USER:$SUDO_USER /home/$SUDO_USER/.config/lxsession
    
    echo "Setting LXTerminal dark background..."
    sudo mkdir -p /home/$SUDO_USER/.config/lxterminal
    sudo bash -c "echo -e '[general]\nbgcolor=#000000\nfgcolor=#ffffff' > /home/$SUDO_USER/.config/lxterminal/lxterminal.conf"
    sudo chown -R $SUDO_USER:$SUDO_USER /home/$SUDO_USER/.config/lxterminal
    
    echo "Forcing Dark Mode in Chromium..."
    sudo mkdir -p /home/$SUDO_USER/.config/chromium-flags.conf
    sudo bash -c "echo '--force-dark-mode' > /home/$SUDO_USER/.config/chromium-flags.conf"
    sudo chown -R $SUDO_USER:$SUDO_USER /home/$SUDO_USER/.config/chromium-flags.conf
    
    echo "Restarting UI components..."
    lxpanelctl restart
    killall pcmanfm 2>/dev/null || true
    
    echo -e "${GREEN}Dark Mode enabled successfully!${NC}"
    echo -e "${YELLOW}Please reboot for all changes to take effect:${NC}"
    echo -e "${YELLOW}sudo reboot${NC}"
}

# Run main process
main 