#!/bin/bash

# NAFO Radio - Because even Russians make backups (they just fail at it)
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Debug mode
DEBUG=true

# Configuration
BACKUP_ROOT="/mnt/data/Backups"
DATE=$(date +%Y-%m-%d)
BACKUP_DIR="$BACKUP_ROOT/$DATE"
LOG_FILE="$BACKUP_ROOT/backup.log"

# Debug function
debug() {
    if [ "$DEBUG" = true ]; then
        echo -e "${YELLOW}DEBUG: $1${NC}" | tee -a "$LOG_FILE"
    fi
}

# Error handling
handle_error() {
    echo -e "${RED}Error: $1${NC}" | tee -a "$LOG_FILE"
    exit 1
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${YELLOW}Requesting sudo access...${NC}"
    exec sudo "$0" "$@"
    exit $?
fi

# Create backup directories
mkdir -p "$BACKUP_DIR"/{system,config,packages,repos,scripts}
mkdir -p "$(dirname "$LOG_FILE")"

# Start logging
echo "=== Backup Started: $(date) ===" >> "$LOG_FILE"

# Function to backup system directories
backup_system() {
    debug "Backing up system directories..."
    
    # Essential system directories
    local dirs=(
        "/etc"
        "/boot"
        "/var/spool/cron"
        "/var/www"
        "/usr/local"
        "/home"
        "/root"
    )
    
    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ]; then
            debug "Backing up $dir"
            tar czf "$BACKUP_DIR/system/$(basename $dir).tar.gz" \
                --exclude="*/lost+found" \
                --exclude="*.log" \
                --exclude=".cache" \
                "$dir" 2>> "$LOG_FILE"
        fi
    done
}

# Function to backup package information
backup_packages() {
    debug "Backing up package information..."
    
    # Package lists
    dpkg --get-selections > "$BACKUP_DIR/packages/package_selections.txt"
    apt-mark showmanual > "$BACKUP_DIR/packages/manual_packages.txt"
    
    # Repository information
    cp -r /etc/apt/sources.list* "$BACKUP_DIR/repos/"
    
    # Get current OS version
    debug "Saving OS information..."
    cat /etc/os-release > "$BACKUP_DIR/system/os_release.txt"
    uname -a > "$BACKUP_DIR/system/kernel.txt"
}

# Function to backup configuration
backup_config() {
    debug "Backing up configuration files..."
    
    # Network configuration
    cp -r /etc/network "$BACKUP_DIR/config/network"
    cp /etc/hostname "$BACKUP_DIR/config/"
    cp /etc/hosts "$BACKUP_DIR/config/"
    
    # SSH configuration
    cp -r /etc/ssh "$BACKUP_DIR/config/ssh"
    
    # Fstab and mount points
    cp /etc/fstab "$BACKUP_DIR/config/"
    
    # User configuration
    cp /etc/passwd "$BACKUP_DIR/config/"
    cp /etc/shadow "$BACKUP_DIR/config/"
    cp /etc/group "$BACKUP_DIR/config/"
    cp /etc/sudoers "$BACKUP_DIR/config/"
}

# Function to backup NAFO Radio scripts
backup_scripts() {
    debug "Backing up NAFO Radio scripts..."
    
    # Get script directory
    local script_dir=$(dirname "$(readlink -f "$0")")
    local project_root=$(dirname "$(dirname "$script_dir")")
    
    # Backup all scripts
    tar czf "$BACKUP_DIR/scripts/nafo_radio_scripts.tar.gz" \
        -C "$project_root" \
        --exclude="*.log" \
        --exclude="*.tmp" \
        .
}

# Function to create recovery instructions
create_recovery_docs() {
    debug "Creating recovery documentation..."
    
    cat > "$BACKUP_DIR/RECOVERY.md" << 'EOF'
# NAFO Radio System Recovery Guide

## System Requirements
- Raspberry Pi (same model as backup source)
- Fresh Raspberry Pi OS installation
- Internet connection

## Recovery Steps

1. Install base system:
   ```bash
   # Install required packages
   sudo apt-get update
   sudo apt-get install $(cat manual_packages.txt)
   ```

2. Restore configurations:
   ```bash
   # Restore /etc configuration
   sudo tar xzf system/etc.tar.gz -C /
   
   # Restore network settings
   sudo cp -r config/network/* /etc/network/
   sudo cp config/hostname /etc/
   sudo cp config/hosts /etc/
   ```

3. Restore user data:
   ```bash
   # Restore home directories
   sudo tar xzf system/home.tar.gz -C /
   
   # Restore user configurations
   sudo cp config/passwd /etc/
   sudo cp config/group /etc/
   ```

4. Restore NAFO Radio scripts:
   ```bash
   # Extract scripts
   sudo tar xzf scripts/nafo_radio_scripts.tar.gz -C /opt/nafo_radio
   ```

5. Update system:
   ```bash
   # Update package lists
   sudo cp -r repos/sources.list* /etc/apt/
   sudo apt-get update
   sudo apt-get upgrade
   ```

6. Verify recovery:
   - Check network connectivity
   - Verify user accounts
   - Test NAFO Radio scripts
   - Check mounted drives
EOF
}

# Main backup process
echo -e "${YELLOW}Starting NAFO Radio system backup...${NC}"

# Create backup structure
debug "Creating backup directory structure..."

# Run backups
backup_system
backup_packages
backup_config
backup_scripts
create_recovery_docs

# Create backup summary
debug "Creating backup summary..."
cat > "$BACKUP_DIR/BACKUP_INFO.md" << EOF
# Backup Information

- Date: $DATE
- System: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
- Kernel: $(uname -r)
- Hostname: $(hostname)
- User: $SUDO_USER

## Contents
- System configurations
- Package information
- Network settings
- User data
- NAFO Radio scripts
- Recovery documentation

## Recovery
See RECOVERY.md for detailed recovery instructions.
EOF

# Create archive of the backup
debug "Creating final backup archive..."
cd "$BACKUP_ROOT"
tar czf "$DATE.tar.gz" "$DATE"
rm -rf "$DATE"

echo -e "${GREEN}Backup complete!${NC}"
echo -e "Backup saved to: $BACKUP_ROOT/$DATE.tar.gz"
echo -e "Log file: $LOG_FILE" 