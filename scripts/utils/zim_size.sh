#!/bin/bash

# Kiwix ZIM repository URL
BASE_URL="https://download.kiwix.org/zim/"

# Color codes for better visibility
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
WHITE='\033[1;37m'
NC='\033[0m'

echo -e "${YELLOW}Scanning Kiwix ZIM directories...${NC}"

# Get list of directories
DIRS=$(curl -s "$BASE_URL" | grep -Eo 'href="[^"]+/"' | sed -E 's/href="([^"]+)"/\1/' | grep -v '^/$\|^\.\./$')

TOTAL_SIZE=0

# Process each directory
for DIR in $DIRS; do
    DIR_NAME=${DIR%/}
    echo -e "\n${WHITE}Checking directory: $DIR_NAME${NC}"
    
    # Get directory listing
    DIR_CONTENT=$(curl -s "${BASE_URL}${DIR}")
    
    # For Wikipedia directory, only look for English maxi files
    if [[ "$DIR_NAME" == "wikipedia" ]]; then
        FILES=$(echo "$DIR_CONTENT" | grep -Eo 'href="[^"]*_en_.*_maxi.*\.zim"' | sed -E 's/href="//' | sed -E 's/"//')
    else
        # For other directories, get all English files
        FILES=$(echo "$DIR_CONTENT" | grep -Eo 'href="[^"]*_en_.*\.zim"' | sed -E 's/href="//' | sed -E 's/"//')
    fi
    
    # Process files in this directory
    for FILE in $FILES; do
        # Get file size from the directory listing
        SIZE=$(echo "$DIR_CONTENT" | grep "$FILE" | grep -Eo '[0-9.]+[KMGT]' | tail -n1)
        
        if [[ -n "$SIZE" ]]; then
            # Convert size to bytes based on unit
            VALUE=$(echo "$SIZE" | sed 's/[KMGT]$//')
            UNIT=$(echo "$SIZE" | grep -o '[KMGT]$')
            
            case $UNIT in
                K) BYTES=$(echo "$VALUE * 1024" | bc | cut -d. -f1) ;;
                M) BYTES=$(echo "$VALUE * 1024 * 1024" | bc | cut -d. -f1) ;;
                G) BYTES=$(echo "$VALUE * 1024 * 1024 * 1024" | bc | cut -d. -f1) ;;
                T) BYTES=$(echo "$VALUE * 1024 * 1024 * 1024 * 1024" | bc | cut -d. -f1) ;;
                *) BYTES=0 ;;
            esac
            
            # Add to total
            TOTAL_SIZE=$((TOTAL_SIZE + BYTES))
            
            # Display file info
            if [[ $BYTES -gt $((1024*1024*1024)) ]]; then
                SIZE_GB=$(echo "scale=2; $BYTES/1024/1024/1024" | bc)
                echo -e "${GREEN}$DIR_NAME/$FILE - $SIZE_GB GB${NC}"
            else
                SIZE_MB=$(echo "scale=2; $BYTES/1024/1024" | bc)
                echo -e "${GREEN}$DIR_NAME/$FILE - $SIZE_MB MB${NC}"
            fi
        else
            echo -e "${RED}Warning: Could not get size for $FILE${NC}"
        fi
    done
done

# Convert and display total size
TOTAL_GB=$(echo "scale=2; $TOTAL_SIZE/1024/1024/1024" | bc)
echo -e "\n${YELLOW}Total Size of All English ZIM Files: $TOTAL_GB GB${NC}" 