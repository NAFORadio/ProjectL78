#!/bin/bash

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Ensure script runs as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root. Try using: sudo $0${NC}"
   exit 1
fi

# Function to detect current user
detect_user() {
    local user=""
    # Try different methods to get the real user
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

# Function to detect filesystem type
detect_fs() {
    local drive=$1
    local fs_type=$(blkid -s TYPE -o value "$drive")
    if [ -z "$fs_type" ]; then
        echo -e "${RED}Could not determine filesystem type for $drive${NC}"
        exit 1
    fi
    echo "$fs_type"
}

# Function to create fstab entry based on filesystem type
create_fstab_entry() {
    local partuuid=$1
    local mount_point=$2
    local fs_type=$3
    local user=$4
    
    case $fs_type in
        ext4)
            echo "PARTUUID=$partuuid $mount_point ext4 defaults,noatime 0 2"
            ;;
        ntfs|fuseblk)
            echo "PARTUUID=$partuuid $mount_point ntfs-3g defaults,uid=$(id -u $user),gid=$(id -g $user),umask=0002 0 0"
            ;;
        exfat)
            echo "PARTUUID=$partuuid $mount_point exfat defaults,uid=$(id -u $user),gid=$(id -g $user),umask=0002 0 0"
            ;;
        *)
            echo -e "${RED}Unsupported filesystem type: $fs_type${NC}"
            exit 1
            ;;
    esac
}

# Function to display drive selection interface
select_drive() {
    echo -e "\n${YELLOW}Available Drives:${NC}"
    echo "----------------------------------------"
    echo -e "ID\tSize\tLabel\tMount\tDevice"
    echo "----------------------------------------"
    
    # Create arrays to store drive information
    declare -a drives=()
    declare -a sizes=()
    declare -a labels=()
    declare -a mounts=()
    
    # Counter for drive IDs
    local count=1
    
    # Get drive information and store in arrays
    while IFS= read -r line; do
        # Skip header lines and empty lines
        if [[ $line =~ "NAME" ]] || [[ -z $line ]] || [[ $line =~ "loop" ]] || [[ $line =~ "ram" ]]; then
            continue
        fi
        
        local device=$(echo "$line" | awk '{print $1}')
        local size=$(echo "$line" | awk '{print $4}')
        local label=$(echo "$line" | awk '{print $6}')
        local mount=$(echo "$line" | awk '{print $7}')
        
        # Only include actual drives and partitions
        if [[ $device =~ ^sd[a-z][0-9]?$ ]] || [[ $device =~ ^nvme[0-9]n[0-9]p[0-9]$ ]]; then
            drives+=("/dev/$device")
            sizes+=("$size")
            labels+=("$label")
            mounts+=("$mount")
            
            # Display drive information
            printf "%d\t%s\t%s\t%s\t/dev/%s\n" \
                   "$count" \
                   "${size:-N/A}" \
                   "${label:-N/A}" \
                   "${mount:-N/A}" \
                   "$device"
            
            ((count++))
        fi
    done < <(lsblk -o NAME,TYPE,FSTYPE,SIZE,MOUNTPOINT,LABEL)
    
    # Prompt for selection
    echo -e "\n${YELLOW}Select a drive by ID (1-$((count-1))) or 'q' to quit:${NC}"
    while true; do
        read -r selection
        
        # Check for quit
        if [[ $selection == "q" ]]; then
            echo -e "${YELLOW}Exiting...${NC}"
            exit 0
        fi
        
        # Validate selection
        if [[ $selection =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -lt "$count" ]; then
            # Return selected drive path
            echo "${drives[$((selection-1))]}"
            return 0
        else
            echo -e "${RED}Invalid selection. Please choose 1-$((count-1)) or 'q' to quit:${NC}"
        fi
    done
}

# Main script
echo -e "${YELLOW}NAFO Radio Drive Mount Utility${NC}"
echo -e "${YELLOW}Detecting current user...${NC}"
CURRENT_USER=$(detect_user)
echo -e "${GREEN}Detected user: $CURRENT_USER${NC}"

# Get drive selection
DRIVE=$(select_drive)

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
FS_TYPE=$(detect_fs "$DRIVE")
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
FSTAB_ENTRY=$(create_fstab_entry "$PARTUUID" "$MOUNT_POINT" "$FS_TYPE" "$CURRENT_USER")

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