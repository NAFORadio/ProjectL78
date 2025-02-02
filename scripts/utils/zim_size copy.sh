#!/bin/bash

# Kiwix ZIM repository URL
BASE_URL="https://download.kiwix.org/zim/"

# Color codes for better visibility
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
WHITE='\033[1;37m'
BLUE='\033[0;34m'
NC='\033[0m'

# Create temp directory
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Initialize total size
TOTAL_SIZE=0

# Debug function
debug() {
    echo -e "${BLUE}DEBUG: $1${NC}" >&2
}

# Function to check if a filename matches our survival criteria and isn't a nopic version
is_survival_content() {
    local filename=$1
    debug "Checking file: $filename"
    
    # Skip nopic versions
    [[ "$filename" =~ _nopic_ ]] && return 1
    
    case "$filename" in
        *survivorlibrary*|*ready.gov*|*zimgit*|*anonymousplanet*|*fas-military-medicine*|\
        *python*|*bash*|*linux*|*raspberry*|*arduino*|*debian*|*alpine*|*arch*|\
        *chemistry*|*mathematics*|*physics*|*biology*|*engineering*|*science*|\
        *medicine*|*medical*|*health*|*surgery*|*anatomy*|*first-aid*|\
        *farming*|*agriculture*|*gardening*|*permaculture*|*water*|*food-preparation*|\
        *philosophy*|*ethics*|*mathematics*|*engineering*|*chemistry*|\
        *prepper*|*survival*|*disaster*|*emergency*|*medical*|*defense*|\
        *wikipedia_en_all_maxi*|*wiktionary_en_all*|*wikibooks_en_all*)
            debug "Match found: $filename"
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to get base name without date
get_base_name() {
    local result=$(echo "$1" | sed -E 's/_[0-9]{4}-[0-9]{2}\.zim$//')
    debug "Base name for $1: $result"
    echo "$result"
}

echo -e "${YELLOW}Starting scan of Kiwix ZIM repository...${NC}"

# Process each directory
for DIR in $(curl -s "$BASE_URL" | grep -Eo 'href="[^"]+/"' | sed -E 's/href="([^"]+)"/\1/' | grep -v '^/$\|^\.\./$'); do
    DIR_NAME=${DIR%/}
    echo -e "\n${YELLOW}Processing directory: $DIR_NAME${NC}"
    
    # Get directory listing
    DIR_CONTENT=$(curl -s "${BASE_URL}${DIR}")
    if [[ -z "$DIR_CONTENT" ]]; then
        echo -e "${RED}Failed to get content for $DIR_NAME${NC}"
        continue
    fi
    
    # Get all ZIM files
    FILES=$(echo "$DIR_CONTENT" | grep -Eo 'href="[^"]*\.zim"' | sed -E 's/href="//' | sed -E 's/"//')
    debug "Found $(echo "$FILES" | grep -c .) ZIM files in $DIR_NAME"
    
    # Clear temp files for this directory
    rm -f "$TEMP_DIR"/*
    
    # First pass: collect all files and find latest versions
    echo "$FILES" | while read -r FILE; do
        [[ -z "$FILE" ]] && continue
        debug "Processing file: $FILE"
        
        if is_survival_content "$FILE"; then
            BASE=$(get_base_name "$FILE")
            DATE=$(echo "$FILE" | grep -Eo '[0-9]{4}-[0-9]{2}')
            SIZE=$(echo "$DIR_CONTENT" | grep "$FILE" | grep -Eo '[0-9.]+[KMGT]' | tail -n1)
            
            debug "Found match: $FILE (Base: $BASE, Date: $DATE, Size: $SIZE)"
            
            if [ -f "$TEMP_DIR/$BASE.date" ]; then
                OLD_DATE=$(cat "$TEMP_DIR/$BASE.date")
                debug "Comparing dates: $DATE > $OLD_DATE"
                if [[ "$DATE" > "$OLD_DATE" ]]; then
                    debug "Newer version found"
                    echo "$DATE" > "$TEMP_DIR/$BASE.date"
                    echo "$FILE" > "$TEMP_DIR/$BASE.file"
                    echo "$SIZE" > "$TEMP_DIR/$BASE.size"
                fi
            else
                debug "First version found"
                echo "$DATE" > "$TEMP_DIR/$BASE.date"
                echo "$FILE" > "$TEMP_DIR/$BASE.file"
                echo "$SIZE" > "$TEMP_DIR/$BASE.size"
            fi
        fi
    done
    
    # Second pass: display latest versions
    for DATE_FILE in "$TEMP_DIR"/*.date; do
        [ -f "$DATE_FILE" ] || continue
        
        BASE=$(basename "$DATE_FILE" .date)
        FILE=$(cat "$TEMP_DIR/$BASE.file")
        SIZE=$(cat "$TEMP_DIR/$BASE.size")
        
        debug "Processing latest version: $FILE ($SIZE)"
        
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
            
            debug "Converted size: $BYTES bytes"
            
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
        fi
    done
done

# Convert and display total size
TOTAL_GB=$(echo "scale=2; $TOTAL_SIZE/1024/1024/1024" | bc)
echo -e "\n${YELLOW}Total Size Required for Information Ark: $TOTAL_GB GB${NC}" 