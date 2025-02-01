#!/bin/bash

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Function to check and escalate privileges
check_privileges() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${YELLOW}Requesting administrative privileges...${NC}"
        exec sudo "$0" "$@"
        exit $?
    fi
}

# Check for dialog installation
check_dialog() {
    if ! command -v dialog >/dev/null 2>&1; then
        echo -e "${YELLOW}Installing dialog...${NC}"
        apt-get update -qq && apt-get install -y dialog
    fi
}

# Function to detect current user
detect_user() {
    local user=""
    for method in "logname" "who am i | awk '{print \$1}'" "echo $SUDO_USER" "id -un"; do
        user=$(eval $method 2>/dev/null)
        if [ ! -z "$user" ] && [ "$user" != "root" ]; then
            echo "$user"
            return 0
        fi
    done
    echo -e "${RED}Could not determine non-root user${NC}"
    exit 1
}

# Function to create drive selection menu
select_drive() {
    # Create temporary files for dialog output
    local temp_file=$(mktemp)
    local drive_file=$(mktemp)
    
    # Get drive information and format for dialog
    lsblk -pln -o NAME,SIZE,TYPE,MOUNTPOINT,LABEL | grep -E 'disk|part' | \
    grep -v -E '/$|/boot|/boot/efi' | \
    awk '{printf "%s\t%s %s %s %s\n", $1, $2, $3, $4, $5}' > "$drive_file"
    
    # Count number of drives
    local num_drives=$(wc -l < "$drive_file")
    
    # Calculate menu height (min 10, max 20)
    local menu_height=$((num_drives + 7))
    if [ $menu_height -gt 20 ]; then
        menu_height=20
    elif [ $menu_height -lt 10 ]; then
        menu_height=10
    fi
    
    # Create dialog menu items
    local dialog_items=""
    while IFS=$'\t' read -r device info; do
        dialog_items="$dialog_items $device \"$info\""
    done < "$drive_file"
    
    # Show dialog menu
    eval dialog --clear --title \"NAFO Radio Drive Mount Utility\" \
         --backtitle \"Select Drive to Mount\" \
         --menu \"Choose the drive to mount:\" \
         $menu_height 70 $num_drives $dialog_items 2>"$temp_file"
    
    local result=$?
    local selected_drive=$(cat "$temp_file")
    
    # Clean up temporary files
    rm -f "$temp_file" "$drive_file"
    
    # Check if user cancelled
    if [ $result -ne 0 ]; then
        echo -e "${YELLOW}Operation cancelled by user${NC}"
        exit 0
    fi
    
    echo "$selected_drive"
}

# Function to show progress
show_progress() {
    local message="$1"
    echo -e "XXX\n$2\n$message\nXXX"
}

# Main script
clear
echo -e "${YELLOW}NAFO Radio Drive Mount Utility${NC}"

# Check privileges at start
check_privileges "$@"

# Check for dialog
check_dialog

# Detect current user
echo -e "${YELLOW}Detecting current user...${NC}"
CURRENT_USER=$(detect_user)
echo -e "${GREEN}Detected user: $CURRENT_USER${NC}"

# Get drive selection with dialog
DRIVE=$(select_drive)
echo -e "${GREEN}Selected drive: $DRIVE${NC}"

# Show mounting progress
(
echo "10" ; show_progress "Validating drive..." 10
sleep 1

# Validate drive exists
if [ ! -b "$DRIVE" ]; then
    echo -e "${RED}Error: Drive $DRIVE not found!${NC}"
    exit 1
fi

echo "20" ; show_progress "Getting PARTUUID..." 20
# Get PARTUUID
PARTUUID=$(blkid -s PARTUUID -o value "$DRIVE")
if [ -z "$PARTUUID" ]; then
    echo -e "${RED}Error: Could not determine PARTUUID for $DRIVE${NC}"
    exit 1
fi

echo "30" ; show_progress "Detecting filesystem..." 30
# Detect filesystem type
FS_TYPE=$(blkid -s TYPE -o value "$DRIVE")
if [ -z "$FS_TYPE" ]; then
    echo -e "${RED}Error: Could not determine filesystem type for $DRIVE${NC}"
    exit 1
fi

echo "40" ; show_progress "Creating mount point..." 40
# Define and create mount point
MOUNT_POINT="/mnt/data"
mkdir -p "$MOUNT_POINT"

echo "50" ; show_progress "Checking current mounts..." 50
# Unmount if already mounted
if mountpoint -q "$MOUNT_POINT"; then
    umount "$MOUNT_POINT"
fi

echo "60" ; show_progress "Mounting drive..." 60
# Mount drive
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

echo "70" ; show_progress "Setting permissions..." 70
# Set permissions
chown -R "$CURRENT_USER:$CURRENT_USER" "$MOUNT_POINT"
chmod -R 775 "$MOUNT_POINT"

echo "80" ; show_progress "Updating fstab..." 80
# Update fstab
FSTAB_ENTRY="PARTUUID=$PARTUUID $MOUNT_POINT $FS_TYPE defaults,uid=$(id -u $CURRENT_USER),gid=$(id -g $CURRENT_USER),umask=0002 0 0"
cp /etc/fstab /etc/fstab.backup
sed -i "\|$MOUNT_POINT|d" /etc/fstab
echo "$FSTAB_ENTRY" >> /etc/fstab

echo "90" ; show_progress "Testing configuration..." 90
# Test fstab
if ! mount -a; then
    mv /etc/fstab.backup /etc/fstab
    exit 1
fi

echo "100" ; show_progress "Complete!" 100
) | dialog --title "Mounting Drive" --gauge "Starting mount process..." 10 70 0

# Final verification
clear
echo -e "${GREEN}Drive mounted successfully!${NC}"
echo -e "${GREEN}Mount will persist across reboots.${NC}"
echo -e "${GREEN}Backup of original fstab saved at /etc/fstab.backup${NC}"
echo -e "\n${YELLOW}Current mount details:${NC}"
df -h "$MOUNT_POINT" 