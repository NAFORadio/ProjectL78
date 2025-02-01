#!/bin/bash

# NAFO Radio - Mount drives like we mount offensives
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Debug mode
DEBUG=true

# Debug function
debug() {
    if [ "$DEBUG" = true ]; then
        echo -e "${YELLOW}DEBUG: $1${NC}"
    fi
}

# Error handling
handle_error() {
    echo -e "${RED}Error: $1${NC}"
    exit 1
}

# Check sudo
if [[ $EUID -ne 0 ]]; then
    echo -e "${YELLOW}Requesting sudo access...${NC}"
    exec sudo "$0" "$@"
    exit $?
fi

# Get real user
CURRENT_USER=$SUDO_USER
if [ -z "$CURRENT_USER" ]; then
    handle_error "Could not determine real user"
fi

debug "Current user: $CURRENT_USER"

# Simple drive listing
echo -e "${YELLOW}Available drives and partitions:${NC}"
echo "----------------------------------------"
debug "Running lsblk..."

# Get drives and partitions
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep -v -E 'loop|ram|boot|^NAME'
if [ $? -ne 0 ]; then
    handle_error "Failed to list drives"
fi

echo "----------------------------------------"

# Drive/Partition selection
while true; do
    echo -e "${YELLOW}Enter partition name (e.g., sda1, nvme0n1p1) or 'q' to quit:${NC}"
    read -r choice
    
    if [ "$choice" = "q" ]; then
        echo -e "${YELLOW}Exiting...${NC}"
        exit 0
    fi
    
    # Check if it's a partition
    if [[ ! "$choice" =~ p[0-9]+$ ]] && [[ ! "$choice" =~ [0-9]+$ ]]; then
        echo -e "${RED}Please select a partition, not a disk (e.g., nvme0n1p1, not nvme0n1)${NC}"
        continue
    fi
    
    if [ -b "/dev/$choice" ]; then
        DRIVE="/dev/$choice"
        break
    else
        echo -e "${RED}Invalid partition. Try again.${NC}"
    fi
done

debug "Selected partition: $DRIVE"

# Get drive info
debug "Getting PARTUUID..."
PARTUUID=$(blkid -s PARTUUID -o value "$DRIVE")
if [ -z "$PARTUUID" ]; then
    handle_error "Could not get PARTUUID. Is this a formatted partition?"
fi

debug "Getting filesystem type..."
FS_TYPE=$(blkid -s TYPE -o value "$DRIVE")
if [ -z "$FS_TYPE" ]; then
    handle_error "Could not get filesystem type. Is this partition formatted?"
fi

echo -e "${GREEN}Partition: $DRIVE${NC}"
echo -e "${GREEN}Type: $FS_TYPE${NC}"
echo -e "${GREEN}PARTUUID: $PARTUUID${NC}"

# Mount point
MOUNT_POINT="/mnt/data"
debug "Creating mount point..."
mkdir -p "$MOUNT_POINT"

# Unmount if needed
if mountpoint -q "$MOUNT_POINT"; then
    debug "Unmounting existing mount..."
    umount "$MOUNT_POINT"
fi

# Mount
echo -e "${YELLOW}Mounting partition...${NC}"
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

if [ $? -ne 0 ]; then
    handle_error "Mount failed"
fi

# Set permissions
debug "Setting permissions..."
chown -R "$CURRENT_USER:$CURRENT_USER" "$MOUNT_POINT"
chmod -R 775 "$MOUNT_POINT"

# Update fstab
debug "Updating fstab..."
FSTAB_ENTRY="PARTUUID=$PARTUUID $MOUNT_POINT $FS_TYPE defaults,uid=$(id -u $CURRENT_USER),gid=$(id -g $CURRENT_USER),umask=0002 0 0"

# Backup fstab
cp /etc/fstab /etc/fstab.backup

# Update entry
sed -i "\|$MOUNT_POINT|d" /etc/fstab
echo "$FSTAB_ENTRY" >> /etc/fstab

# Test mount
echo -e "${YELLOW}Testing mount configuration...${NC}"
if mount -a; then
    echo -e "${GREEN}Success! Drive mounted at $MOUNT_POINT${NC}"
    echo -e "${GREEN}Mount will persist across reboots${NC}"
    df -h "$MOUNT_POINT"
else
    mv /etc/fstab.backup /etc/fstab
    handle_error "Mount test failed"
fi 