#!/bin/bash
# RAID configuration module

source "$(dirname "$0")/../common/utils.sh"

setup_raid_array() {
    log_message "Setting up RAID 1 array..."
    
    # Install RAID tools
    apt-get update && apt-get install -y mdadm smartmontools
    
    # Check for existing arrays
    if mdadm --detail /dev/md0 &>/dev/null; then
        log_message "${YELLOW}RAID array already exists${NC}"
        return 0
    fi
    
    # Create array
    mdadm --create --verbose /dev/md0 --level=1 --raid-devices=2 /dev/nvme0n1 /dev/nvme1n1 || {
        handle_error "RAID creation failed"
    }
    
    # Monitor sync progress
    while [ $(cat /proc/mdstat | grep -c "recovery") -gt 0 ]; do
        progress=$(grep -m1 recovery /proc/mdstat | awk '{print $4}')
        log_message "RAID sync progress: $progress"
        sleep 30
    done
    
    # Save configuration
    mdadm --detail --scan >> /etc/mdadm/mdadm.conf
    update-initramfs -u
    
    log_message "${GREEN}RAID setup complete${NC}"
} 