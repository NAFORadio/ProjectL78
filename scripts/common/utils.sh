#!/bin/bash
# Common utilities and variables

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Paths
LOG_FILE="/var/log/nafo_radio_install.log"
PROGRESS_FILE="/var/log/nafo_radio_progress.txt"
STORAGE_ROOT="/storage"
CONFIG_DIR="/etc/nafo_radio"

# Logging function
log_message() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} - ${message}" | tee -a "$LOG_FILE"
}

# Root check
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        log_message "${RED}Please run as root${NC}"
        exit 1
    fi
}

# Progress tracking
create_progress_file() {
    cat > "$PROGRESS_FILE" << EOF
NAFO RADIO INSTALLATION PROGRESS
===============================
[ ] Base System Installation
[ ] RAID Configuration
[ ] Network Setup
[ ] Software Installation
[ ] Directory Structure
[ ] Service Configuration
[ ] Security Setup
[ ] Database Initialization
[ ] Content Download
EOF
}

# Error handling
handle_error() {
    local error_message="$1"
    log_message "${RED}ERROR: ${error_message}${NC}"
    exit 1
} 