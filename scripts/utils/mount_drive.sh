#!/bin/bash

# NAFO Radio - Because Vatniks can't handle organized data storage
# Fellas, let's mount some drives and make Russian IT cry

# Color codes for output - As bright as Ukrainian victory
GREEN='\033[0;32m'    # For successful hits
YELLOW='\033[1;33m'   # For warning shots
RED='\033[0;31m'      # For vatnik errors
NC='\033[0m'          # Reset like Russian morale

# Function to check privileges - More verification than Russian casualty numbers
check_privileges() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${YELLOW}Requesting administrative privileges (unlike Russian chain of command)...${NC}"
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

# Check for dialog installation
install_dialog() {
    if ! command -v dialog >/dev/null 2>&1; then
        echo -e "${YELLOW}Installing dialog...${NC}"
        apt-get update -qq && apt-get install -y dialog
    fi
}

# Function to list available drives
list_drives() {
    lsblk -pln -o NAME,SIZE,TYPE,MOUNTPOINT,LABEL | \
    grep -E 'disk|part' | \
    grep -v -E '/$|/boot|/boot/efi'
}

# Function to create drive selection menu
select_drive() {
    local temp_file=$(mktemp)
    local drive_list="$(list_drives)"
    
    if [ -z "$drive_list" ]; then
        echo -e "${RED}No suitable drives found${NC}"
        exit 1
    fi
    
    # Convert drive list to dialog menu format
    local menu_items=""
    while IFS= read -r line; do
        local device=$(echo "$line" | awk '{print $1}')
        local info=$(echo "$line" | awk '{print $2, $3, $4, $5}')
        menu_items="$menu_items $device \"$info\""
    done <<< "$drive_list"
    
    # Show dialog menu
    eval dialog --clear --title \"NAFO Radio Drive Mount Utility\" \
         --menu \"Select drive to mount:\" 15 60 8 $menu_items 2>"$temp_file"
    
    local result=$?
    local selected_drive=$(cat "$temp_file")
    rm -f "$temp_file"
    
    if [ $result -ne 0 ]; then
        echo -e "${YELLOW}Operation cancelled${NC}"
        exit 0
    fi
    
    echo "$selected_drive"
}

# Main script
clear
echo -e "${YELLOW}NAFO Radio Drive Mount Utility${NC}"

# Check privileges
check_privileges "$@"

# Install dialog if needed
install_dialog

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

# Validate drive exists
if [ ! -b "$DRIVE" ]; then
    echo -e "${RED}Error: Drive $DRIVE not found!${NC}"
    exit 1
fi

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