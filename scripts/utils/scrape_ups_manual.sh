#!/bin/bash

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
DOCS_DIR="/storage/library/Reference/Hardware/UPS"
URL="https://www.waveshare.com/wiki/UPS_HAT_(E)"
IMAGES_DIR="${DOCS_DIR}/images"

# Ensure running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# Setup logging
LOG_FILE="/var/log/nafo_ups_scraper.log"
exec 1> >(tee -a "$LOG_FILE") 2>&1

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Check required tools
check_dependencies() {
    local deps=(wget curl lynx pandoc)
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_message "Installing $dep..."
            apt-get install -y "$dep"
        fi
    done
}

# Create directory structure
setup_directories() {
    mkdir -p "$DOCS_DIR"
    mkdir -p "$IMAGES_DIR"
}

# Download and process images
download_images() {
    log_message "Downloading images..."
    
    # Extract image URLs from the page
    curl -s "$URL" | grep -o 'https://www\.waveshare\.com/[^"]*\.\(jpg\|png\)' | while read -r img_url; do
        local img_name=$(basename "$img_url")
        log_message "Downloading $img_name"
        wget -q "$img_url" -O "${IMAGES_DIR}/${img_name}"
    done
}

# Download and format the main documentation
download_documentation() {
    log_message "Downloading main documentation..."
    
    # Create markdown file
    local markdown_file="${DOCS_DIR}/ups_hat_e_manual.md"
    
    # Add header
    cat > "$markdown_file" << EOF
# UPS HAT (E) Manual
**Scraped from: $URL**
**Date: $(date '+%Y-%m-%d')**

EOF
    
    # Download and convert to markdown
    lynx -dump -nolist "$URL" | sed 's/\[[0-9]*\]//g' > "${DOCS_DIR}/raw_content.txt"
    
    # Process and format content
    {
        echo "## Table of Contents"
        echo
        grep "^[0-9]\." "${DOCS_DIR}/raw_content.txt"
        echo
        echo "## Content"
        echo
        cat "${DOCS_DIR}/raw_content.txt"
    } >> "$markdown_file"
    
    # Clean up
    rm "${DOCS_DIR}/raw_content.txt"
    
    # Create PDF version
    log_message "Creating PDF version..."
    pandoc "$markdown_file" \
        --from markdown \
        --to pdf \
        --output "${DOCS_DIR}/ups_hat_e_manual.pdf" \
        --toc \
        --highlight-style tango \
        --variable geometry:margin=1in
}

# Download code examples
download_code_examples() {
    log_message "Downloading code examples..."
    
    local code_dir="${DOCS_DIR}/code_examples"
    mkdir -p "$code_dir"
    
    # Download the demo code archive
    wget -q "https://files.waveshare.com/wiki/UPS-HAT-(E)/UPS_HAT_E.7z" -O "${code_dir}/UPS_HAT_E.7z"
    
    # Extract if 7zip is available
    if command -v 7zr &> /dev/null; then
        7zr x "${code_dir}/UPS_HAT_E.7z" -o"${code_dir}" -y
    else
        log_message "${YELLOW}7zip not installed. Archive left compressed.${NC}"
    fi
}

# Save important notes and warnings
save_important_notes() {
    local notes_file="${DOCS_DIR}/IMPORTANT_NOTES.md"
    
    cat > "$notes_file" << 'EOF'
# Important Notes and Warnings for UPS HAT (E)

## Safety Cautions
- Li-ion and Li-po batteries are unstable and may cause fire, injury, or damage if misused
- Do not reverse battery polarities
- Do not mix old and new batteries
- Use only compatible batteries from formal manufacturers
- Replace batteries after max cycle life or two years
- Keep away from inflammables and children

## Critical Usage Notes
1. Battery Connection:
   - Do not charge when batteries are connected reversely
   - Install batteries in V1-V2-V3-V4 order
   - Reconnect to charger after battery replacement to activate output

2. Battery Capacity:
   - New batteries need several charge cycles for accurate readings
   - Capacity readings affected by battery type and temperature
   - Use voltage readings for charge status

3. Power Output:
   - Maximum recommended output: 6A
   - Active cooling needed for higher currents
   - Type-C supports up to 40W power

4. Raspberry Pi 5 Compatibility:
   - Add "PSU_MAX_CURRENT=5000" to eeprom for 5A current
   - Add "usb_max_current_enable=1" to config.txt if power limited

5. Automatic Restart:
   - Set register 0x01 to 0x55 for auto-restart on power
   - Shutdown immediately after setting to avoid data loss
EOF
}

# Main function
main() {
    log_message "Starting UPS manual scraping..."
    
    check_dependencies
    setup_directories
    download_images
    download_documentation
    download_code_examples
    save_important_notes
    
    log_message "${GREEN}Documentation scraping complete!${NC}"
    echo -e "\nDocumentation saved to: ${DOCS_DIR}"
    echo -e "Important notes saved to: ${DOCS_DIR}/IMPORTANT_NOTES.md"
    echo -e "Code examples saved to: ${DOCS_DIR}/code_examples"
}

# Run main process
main 