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
IMPORTANT_PATHS=(
    "/etc"
    "/home"
    "/root"
    "/var/log"
    "/var/www"
    "/opt"
)

# Ensure running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# Setup logging
LOG_FILE="/var/log/nafo_backup.log"
exec 1> >(tee -a "$LOG_FILE") 2>&1

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Initialize borg repository if needed
setup_borg_repo() {
    # Create mount point if it doesn't exist
    mkdir -p "$BACKUP_MOUNT"
    
    # Check if drive is mounted
    if ! mountpoint -q "$BACKUP_MOUNT"; then
        # Format if necessary (first time)
        if ! blkid "$BACKUP_DRIVE" > /dev/null; then
            log_message "Formatting backup drive..."
            mkfs.ext4 -L NAFO_BACKUP "$BACKUP_DRIVE"
        fi
        
        # Mount drive
        mount "$BACKUP_DRIVE" "$BACKUP_MOUNT"
        if [ $? -ne 0 ]; then
            log_message "${RED}Failed to mount backup drive${NC}"
            exit 1
        fi
    fi
    
    # Initialize borg repo if it doesn't exist
    if [ ! -d "$BORG_REPO" ]; then
        log_message "Initializing borg repository..."
        borg init --encryption=repokey "$BORG_REPO"
        if [ $? -ne 0 ]; then
            log_message "${RED}Failed to initialize borg repository${NC}"
            exit 1
        fi
    fi
}

# Create backup
create_backup() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    log_message "Starting backup: ${timestamp}"
    
    # Create backup
    borg create \
        --verbose \
        --filter AME \
        --list \
        --stats \
        --show-rc \
        --compression lz4 \
        --exclude-caches \
        --exclude '/proc/*' \
        --exclude '/sys/*' \
        --exclude '/dev/*' \
        --exclude '/run/*' \
        --exclude '/tmp/*' \
        --exclude '/var/tmp/*' \
        --exclude '/var/cache/*' \
        --exclude '/var/run/*' \
        --exclude '/media/*' \
        --exclude '/mnt/*' \
        --exclude '*.log' \
        --exclude '*.pid' \
        --exclude '*.sock' \
        "${BORG_REPO}::${timestamp}" \
        "${IMPORTANT_PATHS[@]}"
    
    local result=$?
    if [ $result -eq 0 ]; then
        log_message "${GREEN}Backup created successfully${NC}"
    else
        log_message "${RED}Backup failed with code $result${NC}"
        return 1
    fi
}

# Prune old backups
prune_old_backups() {
    log_message "Pruning old backups..."
    
    borg prune \
        --keep-hourly 24 \
        --keep-daily 7 \
        --keep-weekly 4 \
        --keep-monthly 6 \
        "$BORG_REPO"
    
    if [ $? -eq 0 ]; then
        log_message "${GREEN}Old backups pruned successfully${NC}"
    else
        log_message "${RED}Backup pruning failed${NC}"
        return 1
    fi
}

# Main backup process
main() {
    log_message "Starting backup process..."
    
    setup_borg_repo
    create_backup
    prune_old_backups
    
    log_message "Backup process complete"
}

# Run main process
main 