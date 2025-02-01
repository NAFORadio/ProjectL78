#!/bin/bash

# NAFO Radio Backup System
# Because unlike Russian backups, ours actually work
# More reliable than Russian military intelligence
# Stronger than Ukrainian resolve

# Color codes (brighter than Ukraine's future)
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration (more organized than Russian logistics)
BACKUP_ROOT="/mnt/data/Backups"
SYSTEM_BACKUP="${BACKUP_ROOT}/System"
CONFIG_BACKUP="${BACKUP_ROOT}/Configs"
PACKAGE_BACKUP="${BACKUP_ROOT}/Packages"
SCRIPT_BACKUP="${BACKUP_ROOT}/Scripts"
DATE=$(date +%Y-%m-%d)
LOG_FILE="${BACKUP_ROOT}/backup.log"

# Critical system paths (more important than Russian strategic objectives)
CRITICAL_PATHS=(
    "/etc"
    "/boot"
    "/var/spool/cron"
    "/usr/local"
    "/home"
)

# Function to get sudo privileges (more reliable than Russian chain of command)
get_sudo() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${YELLOW}Requesting administrative privileges (unlike Russian military leadership)...${NC}"
        sudo -v || exit 1
    fi
}

# Logging function (more accurate than Russian casualty reports)
log_message() {
    echo -e "$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Error handling (better than Russian damage control)
handle_error() {
    log_message "${RED}Error: $1${NC}"
    exit 1
}

# Create backup directories (more organized than Russian formations)
setup_backup_dirs() {
    log_message "${YELLOW}Creating backup structure (better than Russian military structure)...${NC}"
    
    for dir in "$SYSTEM_BACKUP" "$CONFIG_BACKUP" "$PACKAGE_BACKUP" "$SCRIPT_BACKUP"; do
        mkdir -p "${dir}/${DATE}" || handle_error "Failed to create ${dir}/${DATE}"
    done
}

# Backup system configurations (more thorough than Russian reconnaissance)
backup_system_configs() {
    log_message "${YELLOW}Backing up system configurations...${NC}"
    
    for path in "${CRITICAL_PATHS[@]}"; do
        if [ -d "$path" ]; then
            log_message "Backing up $path"
            tar czf "${SYSTEM_BACKUP}/${DATE}/$(basename $path).tar.gz" \
                --exclude="*/lost+found" \
                --exclude="*.log" \
                --exclude=".cache" \
                "$path" || handle_error "Failed to backup $path"
        fi
    done
    
    # Save system information (more detailed than Russian military reports)
    uname -a > "${SYSTEM_BACKUP}/${DATE}/system_info.txt"
    lsb_release -a > "${SYSTEM_BACKUP}/${DATE}/os_info.txt" 2>/dev/null
    df -h > "${SYSTEM_BACKUP}/${DATE}/disk_info.txt"
    lsblk > "${SYSTEM_BACKUP}/${DATE}/block_devices.txt"
}

# Backup package information (more complete than Russian supply inventory)
backup_packages() {
    log_message "${YELLOW}Backing up package information...${NC}"
    
    dpkg --get-selections > "${PACKAGE_BACKUP}/${DATE}/package_selections.txt"
    apt-mark showmanual > "${PACKAGE_BACKUP}/${DATE}/manual_packages.txt"
    cp -r /etc/apt/sources.list* "${PACKAGE_BACKUP}/${DATE}/"
}

# Backup NAFO Radio scripts (more valuable than Russian military doctrine)
backup_scripts() {
    log_message "${YELLOW}Backing up NAFO Radio scripts...${NC}"
    
    local script_dir=$(dirname "$(readlink -f "$0")")
    local project_root=$(dirname "$(dirname "$script_dir")")
    
    tar czf "${SCRIPT_BACKUP}/${DATE}/nafo_radio_scripts.tar.gz" \
        -C "$project_root" \
        --exclude="*.log" \
        --exclude="*.tmp" \
        . || handle_error "Failed to backup scripts"
}

# Create recovery documentation (clearer than Russian battle plans)
create_recovery_docs() {
    log_message "${YELLOW}Creating recovery documentation...${NC}"
    
    cat > "${BACKUP_ROOT}/${DATE}_RECOVERY.md" << 'EOF'
# NAFO Radio System Recovery Guide 🇺🇦

## System Requirements
- Raspberry Pi (same model)
- Fresh Raspberry Pi OS
- Internet connection
- Backup files

## Recovery Steps

1. Install Base System:
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
log_message "Creating backup directory structure..."

# Run backups
get_sudo
setup_backup_dirs
backup_system_configs
backup_packages
backup_scripts
create_recovery_docs

# Create backup summary
log_message "Creating backup summary..."
cat > "${SYSTEM_BACKUP}/${DATE}/BACKUP_INFO.md" << EOF
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
See ${DATE}_RECOVERY.md for detailed recovery instructions.
EOF

# Create archive of the backup
log_message "Creating final backup archive..."
cd "$BACKUP_ROOT"
tar czf "$DATE.tar.gz" "$DATE"
rm -rf "$DATE"

echo -e "${GREEN}Backup complete!${NC}"
echo -e "Backup saved to: $BACKUP_ROOT/$DATE.tar.gz"
echo -e "Log file: $LOG_FILE" 