#!/bin/bash

# Color codes for output
RED='\033[0;31m'
BLINK_RED='\033[5;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# Multiple confirmation functions to prevent accidental execution
confirm_destruction() {
    echo -e "\n${BLINK_RED}!!! DANGER - EXTREME CAUTION !!!${NC}"
    echo -e "${RED}This script will PERMANENTLY DESTROY ALL DATA on this system!${NC}"
    echo -e "${RED}This action is IRREVERSIBLE!${NC}"
    echo
    echo "To proceed, please type the following phrase exactly:"
    echo -e "${YELLOW}I understand this will destroy everything${NC}"
    read -p "> " confirm1
    
    if [[ ! "$confirm1" == "I understand this will destroy everything" ]]; then
        echo -e "${GREEN}Operation cancelled. Your system is safe.${NC}"
        exit 1
    fi
    
    echo
    echo -e "${RED}FINAL WARNING: Are you absolutely certain?${NC}"
    echo "Type 'YES' in all caps to proceed:"
    read -p "> " confirm2
    
    if [[ ! "$confirm2" == "YES" ]]; then
        echo -e "${GREEN}Operation cancelled. Your system is safe.${NC}"
        exit 1
    fi
}

# Function to unmount all non-essential filesystems
unmount_filesystems() {
    echo "Unmounting non-essential filesystems..."
    for mount in $(mount | grep -v -E "^/(dev|proc|sys|run)" | cut -d ' ' -f 3); do
        umount -f "$mount" 2>/dev/null
    done
}

# Function to stop all services and processes
stop_services() {
    echo "Stopping services..."
    systemctl stop NetworkManager 2>/dev/null
    systemctl stop apache2 2>/dev/null
    systemctl stop nginx 2>/dev/null
    systemctl stop mysql 2>/dev/null
    systemctl stop postgresql 2>/dev/null
    
    # Kill remaining user processes
    killall -9 -u $(whoami) 2>/dev/null
}

# Function to destroy RAID arrays if present
destroy_raid() {
    echo "Destroying RAID arrays..."
    if command -v mdadm &>/dev/null; then
        mdadm --stop /dev/md* 2>/dev/null
        mdadm --zero-superblock /dev/sd* 2>/dev/null
        mdadm --zero-superblock /dev/nvme* 2>/dev/null
    fi
}

# Main destruction function
destroy_system() {
    echo -e "\n${RED}Beginning system destruction...${NC}"
    
    # Stop services and processes
    stop_services
    
    # Destroy RAID arrays
    destroy_raid
    
    # Unmount filesystems
    unmount_filesystems
    
    echo "Destroying file systems..."
    
    # Overwrite all block devices with random data
    for device in $(lsblk -dpno NAME | grep -v -E "^/dev/loop"); do
        echo "Wiping $device..."
        dd if=/dev/urandom of="$device" bs=1M count=100 2>/dev/null
    done
    
    # Remove all files starting from root
    echo "Removing all files..."
    rm -rf /* 2>/dev/null
    
    echo -e "${RED}System destruction complete.${NC}"
    echo -e "${RED}The system will likely become unresponsive now.${NC}"
    echo -e "${RED}Power off the machine and reinstall the operating system.${NC}"
}

# Main execution
echo -e "${RED}NAFO Radio System Destruction Utility${NC}"
confirm_destruction
destroy_system 