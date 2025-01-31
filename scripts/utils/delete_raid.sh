#!/bin/bash

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# Function to detect and list RAID arrays
list_raids() {
    echo -e "\n${YELLOW}Detecting RAID arrays...${NC}"
    if ! mdadm --detail /dev/md* 2>/dev/null; then
        echo -e "${RED}No RAID arrays found.${NC}"
        exit 0
    fi
}

# Function to confirm deletion
confirm_deletion() {
    echo -e "\n${RED}WARNING: This will destroy all RAID arrays and their data!${NC}"
    read -p "Are you absolutely sure you want to continue? (yes/N): " confirm
    if [[ ! $confirm == "yes" ]]; then
        echo -e "${YELLOW}Operation cancelled.${NC}"
        exit 1
    fi
}

# Main function to delete RAID
delete_raid() {
    echo -e "\n${YELLOW}Starting RAID deletion process...${NC}"

    # Unmount any mounted RAID arrays
    echo "Unmounting RAID arrays..."
    for md in /dev/md*; do
        if [ -b "$md" ]; then
            umount "$md" 2>/dev/null
        fi
    done

    # Stop all RAID arrays
    echo "Stopping RAID arrays..."
    mdadm --stop /dev/md* 2>/dev/null

    # Find and zero superblocks on all NVMe drives
    echo "Clearing superblocks..."
    for drive in /dev/nvme?n1; do
        if [ -b "$drive" ]; then
            echo "Clearing superblock on $drive"
            mdadm --zero-superblock "$drive" 2>/dev/null
        fi
    done

    # Remove RAID configuration
    echo "Removing RAID configuration..."
    if [ -f "/etc/mdadm/mdadm.conf" ]; then
        sed -i '/ARRAY/d' /etc/mdadm/mdadm.conf
    fi

    # Remove from fstab
    echo "Updating fstab..."
    if [ -f "/etc/fstab" ]; then
        sed -i '/\/dev\/md/d' /etc/fstab
    fi

    # Update initramfs
    echo "Updating initramfs..."
    update-initramfs -u

    echo -e "${GREEN}RAID deletion complete!${NC}"
}

# Main execution
list_raids
confirm_deletion
delete_raid 