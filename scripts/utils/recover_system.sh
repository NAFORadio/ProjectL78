#!/bin/bash

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
BACKUP_DRIVE="/dev/nvme1n1"
BACKUP_MOUNT="/mnt/backup"
BORG_REPO="${BACKUP_MOUNT}/borg_repo"
RESTORE_POINT="/mnt/restore_point"

# Ensure running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# Setup logging
LOG_FILE="/var/log/nafo_recovery.log"
exec 1> >(tee -a "$LOG_FILE") 2>&1

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Mount backup drive
mount_backup_drive() {
    mkdir -p "$BACKUP_MOUNT"
    mount "$BACKUP_DRIVE" "$BACKUP_MOUNT"
    if [ $? -ne 0 ]; then
        log_message "${RED}Failed to mount backup drive${NC}"
        exit 1
    fi
}

# List available backups
list_backups() {
    echo -e "\n${GREEN}Available backups:${NC}"
    borg list "$BORG_REPO"
    if [ $? -ne 0 ]; then
        log_message "${RED}Failed to list backups${NC}"
        exit 1
    fi
}

# Perform recovery
perform_recovery() {
    local backup_name="$1"
    
    echo -e "${YELLOW}WARNING: This will overwrite your current system files!${NC}"
    read -p "Are you sure you want to continue? (yes/NO): " confirm
    if [[ "$confirm" != "yes" ]]; then
        echo "Recovery cancelled"
        exit 0
    fi
    
    log_message "Starting system recovery from ${backup_name}..."
    
    # Create temporary restore point
    mkdir -p "$RESTORE_POINT"
    
    # Extract backup to restore point
    borg extract --list "$BORG_REPO::$backup_name"
    
    if [ $? -eq 0 ]; then
        log_message "${GREEN}Recovery completed successfully${NC}"
        echo -e "\n${GREEN}System has been restored. Please reboot your system.${NC}"
    else
        log_message "${RED}Recovery failed${NC}"
        echo -e "\n${RED}Recovery failed. Please check the logs.${NC}"
    fi
}

# Main recovery process
main() {
    mount_backup_drive
    
    echo "Available backups:"
    list_backups
    
    echo -e "\nEnter the backup name to restore (or 'q' to quit):"
    read -p "> " backup_choice
    
    if [[ "$backup_choice" == "q" ]]; then
        echo "Recovery cancelled"
        exit 0
    fi
    
    perform_recovery "$backup_choice"
}

# Run main process
main 