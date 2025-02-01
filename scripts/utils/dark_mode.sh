#!/bin/bash

# NAFO Radio - Dark Mode Enabler
# Because even our UI needs OPSEC

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Debug mode
DEBUG=true

# Debug function
debug() {
    if [ "$DEBUG" = true ]; then
        echo -e "${YELLOW}DEBUG: $1${NC}"
    fi
}

# Error handling
handle_error() {
    echo -e "${RED}Error: $1${NC}"
    exit 1
}

# Function to get sudo privileges
get_sudo() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${YELLOW}Some operations require administrative privileges.${NC}"
        sudo -v || handle_error "Failed to get administrative privileges"
    fi
}

# Function to install required packages
install_requirements() {
    debug "Installing required packages..."
    sudo apt update
    sudo apt install -y arc-theme lxappearance gtk3-engines-murrine || handle_error "Failed to install required packages"
}

# Function to apply settings for a user
apply_user_settings() {
    local user=$1
    local home_dir=$(eval echo ~$user)
    debug "Applying settings for user: $user (home: $home_dir)"

    # Create directories
    sudo -u $user mkdir -p $home_dir/.config/gtk-3.0
    sudo -u $user mkdir -p $home_dir/.config/lxterminal
    sudo -u $user mkdir -p $home_dir/.config/chromium/Default
    sudo -u $user mkdir -p $home_dir/.config/lxpanel/LXDE-pi/panels

    # GTK3 settings
    sudo -u $user cat > $home_dir/.config/gtk-3.0/settings.ini << EOF
[Settings]
gtk-theme-name=Arc-Dark
gtk-icon-theme-name=Adwaita
gtk-font-name=Sans 10
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=0
gtk-toolbar-style=GTK_TOOLBAR_BOTH_HORIZ
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=0
gtk-menu-images=0
gtk-enable-event-sounds=1
gtk-enable-input-feedback-sounds=1
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
gtk-application-prefer-dark-theme=1
EOF

    # GTK2 settings
    sudo -u $user cat > $home_dir/.gtkrc-2.0 << EOF
gtk-theme-name="Arc-Dark"
gtk-icon-theme-name="Adwaita"
gtk-font-name="Sans 10"
gtk-cursor-theme-name="Adwaita"
gtk-cursor-theme-size=0
gtk-toolbar-style=GTK_TOOLBAR_BOTH_HORIZ
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=0
gtk-menu-images=0
gtk-enable-event-sounds=1
gtk-enable-input-feedback-sounds=1
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle="hintslight"
gtk-xft-rgba="rgb"
EOF

    # Terminal settings
    sudo -u $user cat > $home_dir/.config/lxterminal/lxterminal.conf << EOF
[general]
fontname=Monospace 10
selchars=-A-Za-z0-9,./?%&#:_
scrollback=1000
bgcolor=rgb(0,0,0)
fgcolor=rgb(211,215,207)
palette_color_0=rgb(0,0,0)
palette_color_1=rgb(205,0,0)
palette_color_2=rgb(78,154,6)
palette_color_3=rgb(196,160,0)
palette_color_4=rgb(52,101,164)
palette_color_5=rgb(117,80,123)
palette_color_6=rgb(6,152,154)
palette_color_7=rgb(211,215,207)
palette_color_8=rgb(85,87,83)
palette_color_9=rgb(239,41,41)
palette_color_10=rgb(138,226,52)
palette_color_11=rgb(252,233,79)
palette_color_12=rgb(114,159,207)
palette_color_13=rgb(173,127,168)
palette_color_14=rgb(52,226,226)
palette_color_15=rgb(238,238,236)
color_preset=Custom
EOF

    # Chromium settings
    sudo -u $user cat > $home_dir/.config/chromium/Default/Preferences << EOF
{
   "browser": {
      "custom_chrome_frame": true,
      "enabled_labs_experiments": ["enable-force-dark"]
   }
}
EOF

    # LXDE panel settings
    sudo -u $user cat > $home_dir/.config/lxpanel/LXDE-pi/panels/panel << EOF
# lxpanel <profile> config file
Global {
    edge=bottom
    allign=left
    margin=0
    widthtype=percent
    width=100
    height=26
    transparent=0
    tintcolor=#000000
    alpha=255
    autohide=0
    heightwhenhidden=2
    setdocktype=1
    setpartialstrut=1
    usefontcolor=0
    fontsize=10
    fontcolor=#ffffff
    usefontsize=0
    background=1
    backgroundfile=/usr/share/lxpanel/images/background.png
    iconsize=24
}
EOF

    # Set permissions
    sudo chown -R $user:$user $home_dir/.config
    sudo chown $user:$user $home_dir/.gtkrc-2.0
}

# Function to apply system-wide dark theme
apply_system_theme() {
    debug "Applying system-wide dark theme..."
    
    # Set system-wide GTK3 settings
    sudo mkdir -p /etc/gtk-3.0
    sudo cat > /etc/gtk-3.0/settings.ini << EOF
[Settings]
gtk-theme-name=Arc-Dark
gtk-application-prefer-dark-theme=1
EOF

    # Set default theme for new users
    sudo mkdir -p /etc/skel/.config/gtk-3.0
    sudo cp /etc/gtk-3.0/settings.ini /etc/skel/.config/gtk-3.0/
}

# Main function
main() {
    echo -e "${YELLOW}NAFO Radio Dark Mode Utility${NC}"
    echo -e "${YELLOW}Enabling dark mode across the system...${NC}"
    
    # Get sudo privileges
    get_sudo
    
    # Install requirements
    install_requirements
    
    # Apply system-wide theme
    apply_system_theme
    
    # Apply for all users with home directories
    for user_home in /home/*; do
        if [ -d "$user_home" ]; then
            user=$(basename "$user_home")
            echo -e "${YELLOW}Applying dark mode for user: $user${NC}"
            apply_user_settings "$user"
        fi
    done
    
    # Also apply for root if needed
    if [ -d "/root" ]; then
        echo -e "${YELLOW}Applying dark mode for root user${NC}"
        apply_user_settings "root"
    fi
    
    # Restart UI components
    debug "Restarting UI components..."
    sudo systemctl restart lightdm || true
    
    echo -e "${GREEN}Dark mode enabled system-wide!${NC}"
    echo -e "${YELLOW}Please log out and log back in for all changes to take effect.${NC}"
}

# Run main process
main 