#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Base URL and storage location
BASE_URL="https://download.kiwix.org/zim/"
STORAGE_DIR="$HOME/Desktop/Storage/Zim"
TOTAL_SIZE=0

# Create temp directory
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Debug function
debug() {
    echo -e "${BLUE}DEBUG: $1${NC}" >&2
}

# Function to check if a filename matches our survival criteria
is_survival_content() {
    local filename=$1
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
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

echo -e "${YELLOW}Scanning Kiwix ZIM repository...${NC}"

# Store files to download
declare -a DOWNLOADS=()

# Process each directory
for DIR in $(curl -s "$BASE_URL" | grep -Eo 'href="[^"]+/"' | sed -E 's/href="([^"]+)"/\1/' | grep -v '^/$\|^\.\./$'); do
    DIR_NAME=${DIR%/}
    echo -e "\n${YELLOW}Processing: $DIR_NAME${NC}"
    
    # Get directory listing
    DIR_CONTENT=$(curl -s "${BASE_URL}${DIR}")
    [[ -z "$DIR_CONTENT" ]] && continue
    
    # Process files
    while read -r FILE; do
        [[ -z "$FILE" ]] && continue
        
        if is_survival_content "$FILE"; then
            SIZE=$(echo "$DIR_CONTENT" | grep "$FILE" | grep -Eo '[0-9.]+[KMGT]' | tail -n1)
            if [[ -n "$SIZE" ]]; then
                DOWNLOADS+=("$DIR_NAME/$FILE|$SIZE")
                echo -e "${GREEN}Found: $DIR_NAME/$FILE - $SIZE${NC}"
                
                # Add to total size
                VALUE=$(echo "$SIZE" | sed 's/[KMGT]$//')
                UNIT=$(echo "$SIZE" | grep -o '[KMGT]$')
                case $UNIT in
                    K) BYTES=$(echo "$VALUE * 1024" | bc | cut -d. -f1) ;;
                    M) BYTES=$(echo "$VALUE * 1024 * 1024" | bc | cut -d. -f1) ;;
                    G) BYTES=$(echo "$VALUE * 1024 * 1024 * 1024" | bc | cut -d. -f1) ;;
                    T) BYTES=$(echo "$VALUE * 1024 * 1024 * 1024 * 1024" | bc | cut -d. -f1) ;;
                esac
                TOTAL_SIZE=$((TOTAL_SIZE + BYTES))
            fi
        fi
    done < <(echo "$DIR_CONTENT" | grep -Eo 'href="[^"]*\.zim"' | sed -E 's/href="//' | sed -E 's/"//')
done

# Show summary
TOTAL_GB=$(echo "scale=2; $TOTAL_SIZE/1024/1024/1024" | bc)
echo -e "\n${YELLOW}Total Size Required: $TOTAL_GB GB${NC}"
echo -e "\n${YELLOW}Files to download:${NC}"
printf '%s\n' "${DOWNLOADS[@]}" | cut -d'|' -f1

# Ask for confirmation
echo -e "\n${YELLOW}Download these files? [y/N]${NC}"
read -r response

if [[ "$response" =~ ^[Yy]$ ]]; then
    mkdir -p "$STORAGE_DIR"
    
    for entry in "${DOWNLOADS[@]}"; do
        IFS='|' read -r file size <<< "$entry"
        dir=$(dirname "$file")
        
        mkdir -p "$STORAGE_DIR/$dir"
        echo -e "\n${YELLOW}Downloading: $file ($size)${NC}"
        wget -c "${BASE_URL}${file}" -P "$STORAGE_DIR/$dir"
    done
    
    echo -e "\n${GREEN}Downloads complete!${NC}"
    du -sh "$STORAGE_DIR"
else
    echo -e "${RED}Download cancelled${NC}"
fi 