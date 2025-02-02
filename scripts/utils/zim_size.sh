#!/bin/bash

# Kiwix ZIM repository URL
BASE_URL="https://download.kiwix.org/zim/"

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Create temp directory for tracking processed files
TEMP_DIR=$(mktemp -d)
TOTAL_SIZE=0

# Function to convert human readable size to bytes
to_bytes() {
    local size=$1
    local value=$(echo $size | sed 's/[A-Za-z]*//')
    local unit=$(echo $size | sed 's/[0-9.]*//')
    
    case $unit in
        K) echo "$value * 1024" | bc ;;
        M) echo "$value * 1024 * 1024" | bc ;;
        G) echo "$value * 1024 * 1024 * 1024" | bc ;;
        *) echo $value ;;
    esac
}

# Function to process a directory
process_directory() {
    local dir_url="$1"
    local indent="$2"
    
    echo -e "${YELLOW}${indent}Scanning $dir_url${NC}"
    
    # Get directory listing
    local listing=$(curl -s "$dir_url")
    
    # Process each line of the directory listing
    echo "$listing" | grep -E 'href=".*\.zim".*[0-9]+[KMG]' | while read -r line; do
        # Extract filename and size
        local zim=$(echo "$line" | grep -Eo 'href="[^"]*_en_[^"]*\.zim"' | sed -E 's/href="//' | sed -E 's/"//')
        [ -z "$zim" ] && continue
        
        local size=$(echo "$line" | grep -Eo '[0-9.]+[KMG]' | tail -n1)
        
        # Convert size to bytes
        local size_bytes=$(to_bytes "$size")
        
        # Extract the base name
        local BASE_NAME=$(echo "$zim" | awk -F'_' '{print $1"_"$2"_"$3}')
        
        # If this base name is not already processed
        if [ ! -f "$TEMP_DIR/$BASE_NAME" ]; then
            # Calculate size in GB
            local size_gb=$(echo "scale=2; $size_bytes / 1024 / 1024 / 1024" | bc)
            
            # Format output with padding
            printf "${GREEN}${indent}%-60s %8.2f GB${NC}\n" "$zim" "$size_gb"
            
            TOTAL_SIZE=$((TOTAL_SIZE + size_bytes))
            echo "$zim:$size_bytes" > "$TEMP_DIR/$BASE_NAME"
        fi
    done
    
    # Find and process subdirectories
    echo "$listing" | grep -Eo 'href="[^"]+/"' | sed -E 's/href="([^"]+)"/\1/' | while read -r subdir; do
        [[ "$subdir" == "../" || "$subdir" == "./" ]] && continue
        process_directory "${dir_url}${subdir}" "$indent  "
    done
}

echo -e "${YELLOW}Starting recursive scan of Kiwix ZIM repository...${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Start recursive processing from root
process_directory "$BASE_URL" ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Calculate and display total size in GB
TOTAL_SIZE_GB=$(echo "scale=2; $TOTAL_SIZE / 1024 / 1024 / 1024" | bc)
echo -e "\n${GREEN}Total Size of All English ZIM Files: $TOTAL_SIZE_GB GB${NC}"

# Show summary by category
echo -e "\n${YELLOW}Summary by Category:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
for file in "$TEMP_DIR"/*; do
    if [ -f "$file" ]; then
        category=$(basename "$file" | cut -d'_' -f1)
        size=$(cut -d':' -f2 < "$file")
        size_gb=$(echo "scale=2; $size / 1024 / 1024 / 1024" | bc)
        printf "${GREEN}%-20s %8.2f GB${NC}\n" "$category" "$size_gb"
    fi
done
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Cleanup
rm -rf "$TEMP_DIR" 