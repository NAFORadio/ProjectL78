#!/bin/bash

# NAFO Radio Setup Script
# This script automates the installation and configuration of NAFO Radio system

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Log file setup
LOG_FILE="/var/log/nafo_radio_install.log"
PROGRESS_FILE="progress.txt"

# Function to log messages
log_message() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} - ${message}" | tee -a "$LOG_FILE"
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${RED}Please run as root${NC}"
        exit 1
    fi
}

# Function to check hardware requirements
check_hardware() {
    log_message "Checking hardware requirements..."
    
    # Check RAM
    total_ram=$(free -m | awk '/^Mem:/{print $2}')
    if [ "$total_ram" -lt 7500 ]; then
        log_message "${RED}ERROR: Insufficient RAM. 8GB required.${NC}"
        return 1
    fi
    
    # Check for NVMe drives
    nvme_drives=$(ls /dev/nvme* 2>/dev/null | wc -l)
    if [ "$nvme_drives" -lt 2 ]; then
        log_message "${RED}ERROR: Two NVMe drives required.${NC}"
        return 1
    fi
    
    log_message "${GREEN}Hardware requirements met.${NC}"
    return 0
}

# Function to check for existing RAID
check_existing_raid() {
    if mdadm --detail /dev/md* &>/dev/null; then
        echo -e "${YELLOW}WARNING: Existing RAID array(s) detected.${NC}"
        read -p "Do you want to destroy existing RAID array(s) and create a new one? (y/N): " confirm
        if [[ $confirm =~ ^[Yy]$ ]]; then
            log_message "User confirmed RAID destruction."
            # Stop all arrays
            mdadm --stop /dev/md* &>/dev/null
            # Zero superblocks
            mdadm --zero-superblock /dev/nvme0n1 /dev/nvme1n1
            return 0
        else
            log_message "User declined RAID destruction. Exiting."
            exit 1
        fi
    fi
    return 0
}

# Function to setup RAID
setup_raid() {
    log_message "Setting up RAID 1 array..."
    
    # Install mdadm if not present
    apt-get update && apt-get install -y mdadm
    
    # Check for existing RAID
    check_existing_raid
    
    # Create RAID 1 array
    mdadm --create --verbose /dev/md0 --level=1 --raid-devices=2 /dev/nvme0n1 /dev/nvme1n1
    
    # Wait for array to sync
    log_message "Waiting for RAID array to sync..."
    while [ $(cat /proc/mdstat | grep -c "recovery") -gt 0 ]; do
        sleep 10
    done
    
    # Save RAID configuration
    mdadm --detail --scan >> /etc/mdadm/mdadm.conf
    update-initramfs -u
    
    # Format the RAID array
    log_message "Formatting RAID array..."
    mkfs.ext4 /dev/md0
    
    # Create mount point and mount the array
    mkdir -p /storage
    mount /dev/md0 /storage
    
    # Add to fstab for persistent mounting
    echo "/dev/md0    /storage    ext4    defaults    0    2" >> /etc/fstab
    
    log_message "${GREEN}RAID setup complete and mounted at /storage${NC}"
}

# Function to install required software
install_software() {
    log_message "Installing required software..."
    
    # Update package list
    apt-get update
    
    # Install core packages
    apt-get install -y \
        podman \
        fail2ban \
        ufw \
        smartmontools \
        rsync \
        borgbackup \
        python3-pip \
        git \
        nginx \
        gqrx-sdr \
        rtl-433 \
        dump1090-mutability \
        direwolf
        
    log_message "${GREEN}Software installation complete.${NC}"
}

# Function to create directory structure
create_directory_structure() {
    log_message "Creating directory structure..."
    
    mkdir -p /storage/{library,sensors,radio,backups}
    mkdir -p /storage/library/{Philosophy,Science,History,Survival,Mathematics,Literature,Wikipedia,Reference}
    mkdir -p /storage/sensors/{air_quality,water_quality,soil_data}
    mkdir -p /storage/radio/{sdr_recordings,ham_logs,emergency_freqs}
    mkdir -p /storage/backups/{daily,weekly,monthly}
    
    # Set permissions
    chown -R nafo_admin:nafo_admin /storage
    chmod -R 750 /storage
    
    log_message "${GREEN}Directory structure created.${NC}"
}

# Main installation function
main() {
    check_root
    
    log_message "Starting NAFO Radio installation..."
    
    # Check hardware requirements
    if ! check_hardware; then
        log_message "${RED}Hardware check failed. Exiting.${NC}"
        exit 1
    fi
    
    # Setup RAID
    setup_raid
    
    # Ask user if they want to install software
    read -p "Do you want to install the required software packages now? (y/N): " install_confirm
    if [[ $install_confirm =~ ^[Yy]$ ]]; then
        # Install software
        install_software
        
        # Create directory structure
        create_directory_structure
        
        log_message "${GREEN}NAFO Radio installation complete!${NC}"
    else
        log_message "${YELLOW}Skipping software installation. RAID setup complete!${NC}"
    fi
}

# Run main installation
main "$@" 