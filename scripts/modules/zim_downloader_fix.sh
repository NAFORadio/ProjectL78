#!/bin/bash

# Ensure compatibility with macOS and Debian Linux (Raspberry Pi OS)
if ! command -v wget &> /dev/null; then
    echo "Error: wget is not installed. Please install it using 'brew install wget' (macOS) or 'sudo apt install wget' (Debian)."
    exit 1
fi

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

# Function to check if a filename is in English and relevant
is_valid_file() {
    local filename=$1
    [[ "$filename" =~ _en_ ]] || return 1  # Must be English `_en_`
    
    [[ "$filename" =~ _nopic_ ]] && return 1  # Skip no-picture versions
    
    case "$filename" in
        *wikipedia_en_all_maxi*|*wiktionary_en_all_maxi*|*wikibooks_en_all_maxi*|\
        *gutenberg_en_all_maxi*|*freecodecamp_en_all*|\
        *survivorlibrary*|*ready.gov*|*zimgit*|*anonymousplanet*|*fas-military-medicine*|\
        *python*|*bash*|*linux*|*raspberry*|*arduino*|*debian*|*alpine*|*arch*|\
        *chemistry*|*mathematics*|*physics*|*biology*|*engineering*|*science*|\
        *medicine*|*plato*|*medical*|*health*|*surgery*|*anatomy*|*first-aid*|\
        *farming*|*agriculture*|*gardening*|*permaculture*|*water*|*food-preparation*|\
        *philosophy*|*ethics*|*mathematics*|*engineering*|*chemistry*|\
        *prepper*|*survival*|*disaster*|*emergency*|*medical*|*defense*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

echo -e "${YELLOW}Scanning Kiwix ZIM repository...${NC}"

# Store latest files to download
LATEST_FILES=()
declare -a DOWNLOADS

# Dictionary workaround for macOS compatibility
get_latest_file() {
    local base_name=$1
    local new_file=$2

    for i in "${!LATEST_FILES[@]}"; do
        if [[ "${LATEST_FILES[$i]}" == "$base_name"* ]]; then
            # Compare dates in filenames
            if [[ "$new_file" > "${LATEST_FILES[$i]}" ]]; then
                LATEST_FILES[$i]="$new_file"
            fi
            return
        fi
    done

    # If not found, add new entry
    LATEST_FILES+=("$new_file")
}

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
        
        if is_valid_file "$FILE"; then
            # Extract base filename (without date & extension)
            BASENAME=$(echo "$FILE" | sed -E 's/_20[0-9]{2}-[0-9]{2}.zim//')

            # If it's a maxi version, ensure it's the latest
            if [[ "$FILE" == *"maxi"* ]]; then
                get_latest_file "$BASENAME" "$FILE"
            elif [[ "$FILE" == *"mini"* ]]; then
                # Only add "mini" if no "maxi" exists for the same base
                MAXI_BASENAME="${BASENAME/mini/maxi}"
                if ! [[ " ${LATEST_FILES[@]} " =~ " $MAXI_BASENAME " ]]; then
                    get_latest_file "$BASENAME" "$FILE"
                fi
            else
                # Handle normal files (non-maxi/non-mini)
                get_latest_file "$BASENAME" "$FILE"
            fi
        fi
    done < <(echo "$DIR_CONTENT" | grep -Eo 'href="[^"]*\.zim"' | sed -E 's/href="//' | sed -E 's/"//')
done

# Prepare downloads
for FILE in "${LATEST_FILES[@]}"; do
    DOWNLOADS+=("$FILE")
    echo -e "${GREEN}Selected: $FILE${NC}"
done

# Show summary
TOTAL_GB=$(echo "scale=2; $TOTAL_SIZE/1024/1024/1024" | bc)
echo -e "\n${YELLOW}Total Size Required: $TOTAL_GB GB${NC}"
echo -e "\n${YELLOW}Files to download:${NC}"
printf '%s\n' "${DOWNLOADS[@]}"

# Ask for confirmation
echo -e "\n${YELLOW}Download these files? [y/N]${NC}"
read -r response

if [[ "$response" =~ ^[Yy]$ ]]; then
    mkdir -p "$STORAGE_DIR"
    
    for file in "${DOWNLOADS[@]}"; do
        dir=$(dirname "$file")
        
        mkdir -p "$STORAGE_DIR/$dir"
        echo -e "\n${YELLOW}Downloading: $file${NC}"
        wget -c "${BASE_URL}${file}" -P "$STORAGE_DIR/$dir"
    done
    
    echo -e "\n${GREEN}Downloads complete!${NC}"
    du -sh "$STORAGE_DIR"
else
    echo -e "${RED}Download cancelled${NC}"
fi
#!/bin/bash

# Ensure compatibility with macOS and Debian Linux (Raspberry Pi OS)
if ! command -v wget &> /dev/null; then
    echo "Error: wget is not installed. Please install it using 'brew install wget' (macOS) or 'sudo apt install wget' (Debian)."
    exit 1
fi

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

# Function to check if a filename is in English and relevant
is_valid_file() {
    local filename=$1
    [[ "$filename" =~ _en_ ]] || return 1  # Must be English `_en_`
    
    [[ "$filename" =~ _nopic_ ]] && return 1  # Skip no-picture versions
    
    case "$filename" in
        *wikipedia_en_all_maxi*|*wiktionary_en_all_maxi*|*wikibooks_en_all_maxi*|\
        *gutenberg_en_all_maxi*|*freecodecamp_en_all*|\
        *survivorlibrary*|*ready.gov*|*zimgit*|*anonymousplanet*|*fas-military-medicine*|\
        *python*|*bash*|*linux*|*raspberry*|*arduino*|*debian*|*alpine*|*arch*|\
        *chemistry*|*mathematics*|*physics*|*biology*|*engineering*|*science*|\
        *medicine*|*plato*|*medical*|*health*|*surgery*|*anatomy*|*first-aid*|\
        *farming*|*agriculture*|*gardening*|*permaculture*|*water*|*food-preparation*|\
        *philosophy*|*ethics*|*mathematics*|*engineering*|*chemistry*|\
        *prepper*|*survival*|*disaster*|*emergency*|*medical*|*defense*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

echo -e "${YELLOW}Scanning Kiwix ZIM repository...${NC}"

# Store latest files to download
LATEST_FILES=()
declare -a DOWNLOADS

# Dictionary workaround for macOS compatibility
get_latest_file() {
    local base_name=$1
    local new_file=$2

    for i in "${!LATEST_FILES[@]}"; do
        if [[ "${LATEST_FILES[$i]}" == "$base_name"* ]]; then
            # Compare dates in filenames
            if [[ "$new_file" > "${LATEST_FILES[$i]}" ]]; then
                LATEST_FILES[$i]="$new_file"
            fi
            return
        fi
    done

    # If not found, add new entry
    LATEST_FILES+=("$new_file")
}

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
        
        if is_valid_file "$FILE"; then
            # Extract base filename (without date & extension)
            BASENAME=$(echo "$FILE" | sed -E 's/_20[0-9]{2}-[0-9]{2}.zim//')

            # If it's a maxi version, ensure it's the latest
            if [[ "$FILE" == *"maxi"* ]]; then
                get_latest_file "$BASENAME" "$FILE"
            elif [[ "$FILE" == *"mini"* ]]; then
                # Only add "mini" if no "maxi" exists for the same base
                MAXI_BASENAME="${BASENAME/mini/maxi}"
                if ! [[ " ${LATEST_FILES[@]} " =~ " $MAXI_BASENAME " ]]; then
                    get_latest_file "$BASENAME" "$FILE"
                fi
            else
                # Handle normal files (non-maxi/non-mini)
                get_latest_file "$BASENAME" "$FILE"
            fi
        fi
    done < <(echo "$DIR_CONTENT" | grep -Eo 'href="[^"]*\.zim"' | sed -E 's/href="//' | sed -E 's/"//')
done

# Prepare downloads
for FILE in "${LATEST_FILES[@]}"; do
    DOWNLOADS+=("$FILE")
    echo -e "${GREEN}Selected: $FILE${NC}"
done

# Show summary
TOTAL_GB=$(echo "scale=2; $TOTAL_SIZE/1024/1024/1024" | bc)
echo -e "\n${YELLOW}Total Size Required: $TOTAL_GB GB${NC}"
echo -e "\n${YELLOW}Files to download:${NC}"
printf '%s\n' "${DOWNLOADS[@]}"

# Ask for confirmation
echo -e "\n${YELLOW}Download these files? [y/N]${NC}"
read -r response

if [[ "$response" =~ ^[Yy]$ ]]; then
    mkdir -p "$STORAGE_DIR"
    
    for file in "${DOWNLOADS[@]}"; do
        dir=$(dirname "$file")
        
        mkdir -p "$STORAGE_DIR/$dir"
        echo -e "\n${YELLOW}Downloading: $file${NC}"
        wget -c "${BASE_URL}${file}" -P "$STORAGE_DIR/$dir"
    done
    
    echo -e "\n${GREEN}Downloads complete!${NC}"
    du -sh "$STORAGE_DIR"
else
    echo -e "${RED}Download cancelled${NC}"
fi
#!/bin/bash

# Ensure compatibility with macOS and Debian Linux (Raspberry Pi OS)
if ! command -v wget &> /dev/null; then
    echo "Error: wget is not installed. Please install it using 'brew install wget' (macOS) or 'sudo apt install wget' (Debian)."
    exit 1
fi

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
        *wikipedia_en_all_maxi*|*wiktionary_en_all_maxi*|*wikibooks_en_all_maxi*|\
        *gutenberg_en_all_maxi*|*freecodecamp_en_all*|\
        *survivorlibrary*|*ready.gov*|*zimgit*|*anonymousplanet*|*fas-military-medicine*|\
        *python*|*bash*|*linux*|*raspberry*|*arduino*|*debian*|*alpine*|*arch*|\
        *chemistry*|*mathematics*|*physics*|*biology*|*engineering*|*science*|\
        *medicine*|*plato*|*medical*|*health*|*surgery*|*anatomy*|*first-aid*|\
        *farming*|*agriculture*|*gardening*|*permaculture*|*water*|*food-preparation*|\
        *philosophy*|*ethics*|*mathematics*|*engineering*|*chemistry*|\
        *prepper*|*survival*|*disaster*|*emergency*|*medical*|*defense*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

echo -e "${YELLOW}Scanning Kiwix ZIM repository...${NC}"

# Store latest files to download (use normal arrays instead of associative arrays for macOS compatibility)
LATEST_FILES=()
declare -a DOWNLOADS

# Dictionary workaround for macOS compatibility (since declare -A is not supported in zsh)
get_latest_file() {
    local base_name=$1
    local new_file=$2

    for i in "${!LATEST_FILES[@]}"; do
        if [[ "${LATEST_FILES[$i]}" == "$base_name"* ]]; then
            # Compare dates in filenames
            if [[ "$new_file" > "${LATEST_FILES[$i]}" ]]; then
                LATEST_FILES[$i]="$new_file"
            fi
            return
        fi
    done

    # If not found, add new entry
    LATEST_FILES+=("$new_file")
}

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
            # Extract base filename (without date & extension)
            BASENAME=$(echo "$FILE" | sed -E 's/_20[0-9]{2}-[0-9]{2}.zim//')

            # If it's a maxi version, ensure it's the latest
            if [[ "$FILE" == *"maxi"* ]]; then
                get_latest_file "$BASENAME" "$FILE"
            elif [[ "$FILE" == *"mini"* ]]; then
                # Only add "mini" if no "maxi" exists for the same base
                MAXI_BASENAME="${BASENAME/mini/maxi}"
                if ! [[ " ${LATEST_FILES[@]} " =~ " $MAXI_BASENAME " ]]; then
                    get_latest_file "$BASENAME" "$FILE"
                fi
            else
                # Handle normal files (non-maxi/non-mini)
                get_latest_file "$BASENAME" "$FILE"
            fi
        fi
    done < <(echo "$DIR_CONTENT" | grep -Eo 'href="[^"]*\.zim"' | sed -E 's/href="//' | sed -E 's/"//')
done

# Prepare downloads
for FILE in "${LATEST_FILES[@]}"; do
    DOWNLOADS+=("$FILE")
    echo -e "${GREEN}Selected: $FILE${NC}"
done

# Show summary
TOTAL_GB=$(echo "scale=2; $TOTAL_SIZE/1024/1024/1024" | bc)
echo -e "\n${YELLOW}Total Size Required: $TOTAL_GB GB${NC}"
echo -e "\n${YELLOW}Files to download:${NC}"
printf '%s\n' "${DOWNLOADS[@]}"

# Ask for confirmation
echo -e "\n${YELLOW}Download these files? [y/N]${NC}"
read -r response

if [[ "$response" =~ ^[Yy]$ ]]; then
    mkdir -p "$STORAGE_DIR"
    
    for file in "${DOWNLOADS[@]}"; do
        dir=$(dirname "$file")
        
        mkdir -p "$STORAGE_DIR/$dir"
        echo -e "\n${YELLOW}Downloading: $file${NC}"
        wget -c "${BASE_URL}${file}" -P "$STORAGE_DIR/$dir"
    done
    
    echo -e "\n${GREEN}Downloads complete!${NC}"
    du -sh "$STORAGE_DIR"
else
    echo -e "${RED}Download cancelled${NC}"
fi
#!/bin/bash

# Ensure compatibility with macOS and Debian Linux (Raspberry Pi OS)
if ! command -v wget &> /dev/null; then
    echo "Error: wget is not installed. Please install it using 'brew install wget' (macOS) or 'sudo apt install wget' (Debian)."
    exit 1
fi

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
        *wikipedia_en_all_maxi*|*wiktionary_en_all_maxi*|*wikibooks_en_all_maxi*|\
        *gutenberg_en_all_maxi*|*freecodecamp_en_all*|\
        *survivorlibrary*|*ready.gov*|*zimgit*|*anonymousplanet*|*fas-military-medicine*|\
        *python*|*bash*|*linux*|*raspberry*|*arduino*|*debian*|*alpine*|*arch*|\
        *chemistry*|*mathematics*|*physics*|*biology*|*engineering*|*science*|\
        *medicine*|*plato*|*medical*|*health*|*surgery*|*anatomy*|*first-aid*|\
        *farming*|*agriculture*|*gardening*|*permaculture*|*water*|*food-preparation*|\
        *philosophy*|*ethics*|*mathematics*|*engineering*|*chemistry*|\
        *prepper*|*survival*|*disaster*|*emergency*|*medical*|*defense*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

echo -e "${YELLOW}Scanning Kiwix ZIM repository...${NC}"

# Store latest files to download
declare -A LATEST_FILES
declare -a DOWNLOADS

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
            # Extract base filename (without date & extension)
            BASENAME=$(echo "$FILE" | sed -E 's/_20[0-9]{2}-[0-9]{2}.zim//')

            # Track "maxi" and "mini" versions separately
            if [[ "$FILE" == *"maxi"* ]]; then
                # If a newer "maxi" exists, replace the old one
                if [[ -z "${LATEST_FILES[$BASENAME]}" || "$FILE" > "${LATEST_FILES[$BASENAME]}" ]]; then
                    LATEST_FILES[$BASENAME]="$FILE"
                fi
            elif [[ "$FILE" == *"mini"* ]]; then
                # Only add "mini" if no "maxi" exists for the same base
                MAXI_BASENAME="${BASENAME/mini/maxi}"
                if [[ -z "${LATEST_FILES[$MAXI_BASENAME]}" ]]; then
                    if [[ -z "${LATEST_FILES[$BASENAME]}" || "$FILE" > "${LATEST_FILES[$BASENAME]}" ]]; then
                        LATEST_FILES[$BASENAME]="$FILE"
                    fi
                fi
            else
                # Handle normal files (non-maxi/non-mini)
                if [[ -z "${LATEST_FILES[$BASENAME]}" || "$FILE" > "${LATEST_FILES[$BASENAME]}" ]]; then
                    LATEST_FILES[$BASENAME]="$FILE"
                fi
            fi
        fi
    done < <(echo "$DIR_CONTENT" | grep -Eo 'href="[^"]*\.zim"' | sed -E 's/href="//' | sed -E 's/"//')
done

# Prepare downloads
for FILE in "${LATEST_FILES[@]}"; do
    DOWNLOADS+=("$FILE")
    echo -e "${GREEN}Selected: $FILE${NC}"
done

# Show summary
TOTAL_GB=$(echo "scale=2; $TOTAL_SIZE/1024/1024/1024" | bc)
echo -e "\n${YELLOW}Total Size Required: $TOTAL_GB GB${NC}"
echo -e "\n${YELLOW}Files to download:${NC}"
printf '%s\n' "${DOWNLOADS[@]}"

# Ask for confirmation
echo -e "\n${YELLOW}Download these files? [y/N]${NC}"
read -r response

if [[ "$response" =~ ^[Yy]$ ]]; then
    mkdir -p "$STORAGE_DIR"
    
    for file in "${DOWNLOADS[@]}"; do
        dir=$(dirname "$file")
        
        mkdir -p "$STORAGE_DIR/$dir"
        echo -e "\n${YELLOW}Downloading: $file${NC}"
        wget -c "${BASE_URL}${file}" -P "$STORAGE_DIR/$dir"
    done
    
    echo -e "\n${GREEN}Downloads complete!${NC}"
    du -sh "$STORAGE_DIR"
else
    echo -e "${RED}Download cancelled${NC}"
fi
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
        *wikipedia_en_all_maxi*|*wiktionary_en_all_maxi*|*wikibooks_en_all_maxi*|\
        *gutenberg_en_all_maxi*|*freecodecamp_en_all*|\
        *survivorlibrary*|*ready.gov*|*zimgit*|*anonymousplanet*|*fas-military-medicine*|\
        *python*|*bash*|*linux*|*raspberry*|*arduino*|*debian*|*alpine*|*arch*|\
        *chemistry*|*mathematics*|*physics*|*biology*|*engineering*|*science*|\
        *medicine*|*plato*|*medical*|*health*|*surgery*|*anatomy*|*first-aid*|\
        *farming*|*agriculture*|*gardening*|*permaculture*|*water*|*food-preparation*|\
        *philosophy*|*ethics*|*mathematics*|*engineering*|*chemistry*|\
        *prepper*|*survival*|*disaster*|*emergency*|*medical*|*defense*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

echo -e "${YELLOW}Scanning Kiwix ZIM repository...${NC}"

# Store latest files to download
LATEST_FILES=()
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
            # Extract base filename without date
            BASENAME=$(echo "$FILE" | sed -E 's/_20[0-9]{2}-[0-9]{2}.zim//')
            
            # Check if this file is newer
            FOUND=0
            for i in "${!LATEST_FILES[@]}"; do
                if [[ "${LATEST_FILES[$i]}" == *"$BASENAME"* ]]; then
                    FOUND=1
                    # Compare versions and replace if newer
                    if [[ "$FILE" > "${LATEST_FILES[$i]}" ]]; then
                        LATEST_FILES[$i]="$FILE"
                    fi
                    break
                fi
            done
            
            # If not found, add it
            if [[ $FOUND -eq 0 ]]; then
                LATEST_FILES+=("$FILE")
            fi
        fi
    done < <(echo "$DIR_CONTENT" | grep -Eo 'href="[^"]*\.zim"' | sed -E 's/href="//' | sed -E 's/"//')
done

# Prepare downloads
for FILE in "${LATEST_FILES[@]}"; do
    DOWNLOADS+=("$FILE")
    echo -e "${GREEN}Selected: $FILE${NC}"
done

# Show summary
TOTAL_GB=$(echo "scale=2; $TOTAL_SIZE/1024/1024/1024" | bc)
echo -e "\n${YELLOW}Total Size Required: $TOTAL_GB GB${NC}"
echo -e "\n${YELLOW}Files to download:${NC}"
printf '%s\n' "${DOWNLOADS[@]}"

# Ask for confirmation
echo -e "\n${YELLOW}Download these files? [y/N]${NC}"
read -r response

if [[ "$response" =~ ^[Yy]$ ]]; then
    mkdir -p "$STORAGE_DIR"
    
    for file in "${DOWNLOADS[@]}"; do
        dir=$(dirname "$file")
        
        mkdir -p "$STORAGE_DIR/$dir"
        echo -e "\n${YELLOW}Downloading: $file${NC}"
        wget -c "${BASE_URL}${file}" -P "$STORAGE_DIR/$dir"
    done
    
    echo -e "\n${GREEN}Downloads complete!${NC}"
    du -sh "$STORAGE_DIR"
else
    echo -e "${RED}Download cancelled${NC}"
fi
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
        *wikipedia_en_all_maxi*|*wiktionary_en_all_maxi*|*wikibooks_en_all_maxi*|\
        *gutenberg_en_all_maxi*|*freecodecamp_en_all*|\
        *survivorlibrary*|*ready.gov*|*zimgit*|*anonymousplanet*|*fas-military-medicine*|\
        *python*|*bash*|*linux*|*raspberry*|*arduino*|*debian*|*alpine*|*arch*|\
        *chemistry*|*mathematics*|*physics*|*biology*|*engineering*|*science*|\
        *medicine*|*plato*|*medical*|*health*|*surgery*|*anatomy*|*first-aid*|\
        *farming*|*agriculture*|*gardening*|*permaculture*|*water*|*food-preparation*|\
        *philosophy*|*ethics*|*mathematics*|*engineering*|*chemistry*|\
        *prepper*|*survival*|*disaster*|*emergency*|*medical*|*defense*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

echo -e "${YELLOW}Scanning Kiwix ZIM repository...${NC}"

# Store latest files to download
declare -A LATEST_FILES
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
            # Extract the latest version of each file
            BASENAME=$(echo "$FILE" | sed -E 's/_20[0-9]{2}-[0-9]{2}.zim//')
            
            if [[ -z "${LATEST_FILES[$BASENAME]}" || "$FILE" > "${LATEST_FILES[$BASENAME]}" ]]; then
                LATEST_FILES[$BASENAME]="$FILE"
            fi
        fi
    done < <(echo "$DIR_CONTENT" | grep -Eo 'href="[^"]*\.zim"' | sed -E 's/href="//' | sed -E 's/"//')
done

# Prepare downloads
for FILE in "${LATEST_FILES[@]}"; do
    DOWNLOADS+=("$FILE")
    echo -e "${GREEN}Selected: $FILE${NC}"
done

# Show summary
TOTAL_GB=$(echo "scale=2; $TOTAL_SIZE/1024/1024/1024" | bc)
echo -e "\n${YELLOW}Total Size Required: $TOTAL_GB GB${NC}"
echo -e "\n${YELLOW}Files to download:${NC}"
printf '%s\n' "${DOWNLOADS[@]}"

# Ask for confirmation
echo -e "\n${YELLOW}Download these files? [y/N]${NC}"
read -r response

if [[ "$response" =~ ^[Yy]$ ]]; then
    mkdir -p "$STORAGE_DIR"
    
    for file in "${DOWNLOADS[@]}"; do
        dir=$(dirname "$file")
        
        mkdir -p "$STORAGE_DIR/$dir"
        echo -e "\n${YELLOW}Downloading: $file${NC}"
        wget -c "${BASE_URL}${file}" -P "$STORAGE_DIR/$dir"
    done
    
    echo -e "\n${GREEN}Downloads complete!${NC}"
    du -sh "$STORAGE_DIR"
else
    echo -e "${RED}Download cancelled${NC}"
fi

