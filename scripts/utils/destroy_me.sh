#!/bin/bash

# Color codes for output
RED='\033[0;31m'
BLINK_RED='\033[5;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Ensure the script continues running
trap "" SIGHUP
trap "" SIGTERM
trap "" SIGTSTP

# Set process priority to highest
renice -n -20 $$ > /dev/null 2>&1
ionice -c 1 -n 0 -p $$ > /dev/null 2>&1

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

# Main destruction function
destroy_system() {
    echo -e "\n${RED}Beginning system destruction...${NC}"
    
    # Create a temporary working directory in RAM
    mkdir -p /dev/shm/destroy_temp
    cd /dev/shm/destroy_temp
    
    # Copy essential tools we'll need
    cp $(which dd) ./dd 2>/dev/null
    cp $(which rm) ./rm 2>/dev/null
    cp $(which sync) ./sync 2>/dev/null
    cp $(which mdadm) ./mdadm 2>/dev/null
    
    # First destroy data on drives
    echo "Destroying file systems..."
    for device in $(lsblk -dpno NAME | grep -v -E "^/dev/loop"); do
        echo "Wiping $device..."
        ./dd if=/dev/urandom of="$device" bs=1M count=100 2>/dev/null
        ./sync
    done
    
    # Destroy RAID arrays if present
    if [ -x "./mdadm" ]; then
        echo "Destroying RAID arrays..."
        ./mdadm --stop /dev/md* 2>/dev/null
        ./mdadm --zero-superblock /dev/sd* 2>/dev/null
        ./mdadm --zero-superblock /dev/nvme* 2>/dev/null
    fi
    
    # Now start removing files
    echo "Removing all files..."
    find / -mount -type f -exec ./rm -f {} + 2>/dev/null
    
    # Finally, stop services
    echo "Stopping services..."
    for service in NetworkManager apache2 nginx mysql postgresql; do
        systemctl stop $service 2>/dev/null &
    done
    
    # Kill remaining processes except our shell
    for pid in $(ps -ef | awk '$2 != "'$$'" && $2 != "'$PPID'" {print $2}'); do
        kill -9 $pid 2>/dev/null &
    done
    
    echo -e "${RED}System destruction complete.${NC}"
    echo -e "${RED}The system will become unresponsive after this message.${NC}"
    echo -e "${RED}Power off the machine and reinstall the operating system.${NC}"
    
    # Final cleanup
    cd /
    sync
    rm -rf /dev/shm/destroy_temp
    
    # Kill everything including our shell
    kill -9 -1
}

# Main execution
echo -e "${RED}NAFO Radio System Destruction Utility${NC}"
confirm_destruction
destroy_system 