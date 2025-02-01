#!/bin/bash

# NAFO Radio - Because Vatniks can't handle organized data storage
# Fellas, let's mount some drives and make Russian IT cry

# Color codes for output - As bright as Ukrainian victory
GREEN='\033[0;32m'    # For successful hits
YELLOW='\033[1;33m'   # For warning shots
RED='\033[0;31m'      # For vatnik errors
NC='\033[0m'          # Reset like Russian morale

# Function to check privileges
check_privileges() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${YELLOW}Requesting administrative privileges...${NC}"
        exec sudo "$0" "$@"
        exit $?
    fi
}

# Function to detect current user
detect_user() {
    if [ ! -z "$SUDO_USER" ]; then
        echo "$SUDO_USER"
    else
        logname 2>/dev/null || whoami
    fi
}

# Check for dialog
install_dialog() {
    if ! command -v dialog >/dev/null 2>&1; then
        echo -e "${YELLOW}Installing dialog package...${NC}"
        apt-get update -qq
        apt-get install -y dialog
    fi
}

# Function to select drive
select_drive() {
    echo -e "${YELLOW}Available drives:${NC}"
    echo "----------------------------------------"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep -E 'disk|part' | grep -v -E '/$|/boot|/boot/efi'
    echo "----------------------------------------"
    
    while true; do
        echo -e "${YELLOW}Enter the device name (e.g., sda1) or 'q' to quit:${NC}"
        read -r choice
        
        if [ "$choice" = "q" ]; then
            echo -e "${YELLOW}Operation cancelled${NC}"
            exit 0
        fi
        
        if [ -b "/dev/$choice" ]; then
            echo "/dev/$choice"
            return 0
        else
            echo -e "${RED}Invalid device. Please try again.${NC}"
        fi
    done
}

# Main script
clear
echo -e "${YELLOW}NAFO Radio Drive Mount Utility${NC}"

# Check privileges
check_privileges "$@"

# Detect current user
echo -e "${YELLOW}Detecting current user...${NC}"
CURRENT_USER=$(detect_user)
if [ -z "$CURRENT_USER" ]; then
    echo -e "${RED}Could not detect user${NC}"
    exit 1
fi
echo -e "${GREEN}Detected user: $CURRENT_USER${NC}"

# Get drive selection
echo -e "${YELLOW}Scanning for drives...${NC}"
DRIVE=$(select_drive)

if [ -z "$DRIVE" ]; then
    echo -e "${RED}No drive selected${NC}"
    exit 1
fi

echo -e "${GREEN}Selected drive: $DRIVE${NC}"

# Get PARTUUID
PARTUUID=$(blkid -s PARTUUID -o value "$DRIVE")
if [ -z "$PARTUUID" ]; then
    echo -e "${RED}Error: Could not determine PARTUUID for $DRIVE${NC}"
    exit 1
fi
echo -e "${GREEN}Found PARTUUID: $PARTUUID${NC}"

# Detect filesystem type
FS_TYPE=$(blkid -s TYPE -o value "$DRIVE")
if [ -z "$FS_TYPE" ]; then
    echo -e "${RED}Error: Could not determine filesystem type for $DRIVE${NC}"
    exit 1
fi
echo -e "${GREEN}Detected filesystem: $FS_TYPE${NC}"

# Define mount point
MOUNT_POINT="/mnt/data"

# Create mount point if needed
if [ ! -d "$MOUNT_POINT" ]; then
    echo -e "${YELLOW}Creating mount point at $MOUNT_POINT...${NC}"
    mkdir -p "$MOUNT_POINT"
fi

# Unmount if already mounted
if mountpoint -q "$MOUNT_POINT"; then
    echo -e "${YELLOW}Unmounting existing mount...${NC}"
    umount "$MOUNT_POINT"
fi

# Mount drive
echo -e "${YELLOW}Mounting $DRIVE to $MOUNT_POINT...${NC}"
case $FS_TYPE in
    ntfs|fuseblk)
        mount -t ntfs-3g "$DRIVE" "$MOUNT_POINT" -o uid=$(id -u $CURRENT_USER),gid=$(id -g $CURRENT_USER),umask=0002
        ;;
    exfat)
        mount -t exfat "$DRIVE" "$MOUNT_POINT" -o uid=$(id -u $CURRENT_USER),gid=$(id -g $CURRENT_USER),umask=0002
        ;;
    *)
        mount "$DRIVE" "$MOUNT_POINT"
        ;;
esac

# Set permissions
echo -e "${YELLOW}Setting permissions...${NC}"
chown -R "$CURRENT_USER:$CURRENT_USER" "$MOUNT_POINT"
chmod -R 775 "$MOUNT_POINT"

# Update fstab
echo -e "${YELLOW}Updating /etc/fstab...${NC}"
FSTAB_ENTRY="PARTUUID=$PARTUUID $MOUNT_POINT $FS_TYPE defaults,uid=$(id -u $CURRENT_USER),gid=$(id -g $CURRENT_USER),umask=0002 0 0"

# Backup fstab
cp /etc/fstab /etc/fstab.backup

# Remove any existing entries for this mount point
sed -i "\|$MOUNT_POINT|d" /etc/fstab

# Add new entry
echo "$FSTAB_ENTRY" >> /etc/fstab

# Test fstab
echo -e "${YELLOW}Testing new fstab configuration...${NC}"
if mount -a; then
    echo -e "${GREEN}Drive mounted successfully!${NC}"
    echo -e "${GREEN}Mount will persist across reboots.${NC}"
    echo -e "${GREEN}Backup of original fstab saved at /etc/fstab.backup${NC}"
else
    echo -e "${RED}Error mounting drive. Restoring original fstab...${NC}"
    mv /etc/fstab.backup /etc/fstab
    exit 1
fi

# Final verification
df -h "$MOUNT_POINT" 