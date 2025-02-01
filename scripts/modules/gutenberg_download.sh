#!/bin/bash

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
STORAGE_DIR="/mnt/data/Books"
LOG_FILE="$STORAGE_DIR/logs/gutenberg_download.log"
CATALOG_FILE="$STORAGE_DIR/catalog.csv"

# Gutenberg mirrors with direct book download URLs
MIRRORS=(
    "https://www.gutenberg.org/cache/epub"
    "https://gutenberg.pglaf.org/cache/epub"
    "http://mirrors.xmission.com/gutenberg/cache/epub"
    "http://gutenberg.readingroo.ms/cache/epub"
)

# Topics of interest with search terms
declare -A TOPICS=(
    ["mechanics"]="mechanics|machines|physics|mechanical engineering"
    ["medicine"]="medicine|medical|anatomy|first aid|surgery|healing"
    ["electronics"]="electronics|electrical|circuits|radio|telegraph"
    ["programming"]="programming|computer|python|linux|unix|algorithm"
    ["philosophy"]="philosophy|ethics|logic|reasoning|metaphysics"
    ["civics"]="civics|government|democracy|constitution|law|rights"
    ["art"]="art|drawing|painting|sculpture|design|architecture"
    ["survival"]="survival|wilderness|farming|agriculture|hunting|foraging"
    ["engineering"]="engineering|construction|building|materials|tools"
    ["leadership"]="leadership|management|command|authority|influence|motivation|organization"
    ["military"]="military|strategy|tactics|warfare|combat|defense|army|navy|war|battle|command"
)

# Function to log messages
log_message() {
    echo -e "$1"
    if [ ! -f "$LOG_FILE" ]; then
        mkdir -p "$(dirname "$LOG_FILE")"
    fi
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to get sudo privileges
get_sudo() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${YELLOW}This script requires administrative privileges.${NC}"
        sudo -v
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to get administrative privileges.${NC}"
            exit 1
        fi
    fi
}

# Create storage directory structure
setup_directories() {
    log_message "${YELLOW}Creating directory structure...${NC}"
    mkdir -p "$STORAGE_DIR"/{books,logs,catalog}
    
    # Set permissions
    chown -R $SUDO_USER:$SUDO_USER "$STORAGE_DIR"
    chmod -R 755 "$STORAGE_DIR"
    
    for topic in "${!TOPICS[@]}"; do
        mkdir -p "$STORAGE_DIR/books/$topic"
        chown $SUDO_USER:$SUDO_USER "$STORAGE_DIR/books/$topic"
    done
}

# Function to download a book
download_book() {
    local book_id="$1"
    local title="$2"
    local topic="$3"
    local output_dir="$STORAGE_DIR/books/$topic"
    
    # Create topic directory if it doesn't exist
    mkdir -p "$output_dir"
    
    # Try different formats in order of preference
    for format in pdf epub.noimages txt; do
        for mirror in "${MIRRORS[@]}"; do
            local url="${mirror}/${book_id}/pg${book_id}.${format}"
            log_message "${YELLOW}Attempting to download from: $url${NC}"
            
            if wget -q --spider "$url"; then
                local filename="${book_id}_${title// /_}.${format}"
                if wget -q -O "$output_dir/$filename" "$url"; then
                    log_message "${GREEN}Successfully downloaded: $filename${NC}"
                    echo "$book_id,$title,$topic,$filename,$(date '+%Y-%m-%d')" >> "$CATALOG_FILE"
                    return 0
                fi
            fi
        done
    done
    
    log_message "${RED}Failed to download book ID: $book_id${NC}"
    return 1
}

# Function to process catalog
process_catalog() {
    local catalog_url="https://www.gutenberg.org/cache/epub/feeds/pg_catalog.csv"
    local catalog_file="$STORAGE_DIR/catalog/pg_catalog.csv"
    
    log_message "${YELLOW}Downloading Gutenberg catalog...${NC}"
    mkdir -p "$STORAGE_DIR/catalog"
    
    if ! wget -q -O "$catalog_file" "$catalog_url"; then
        log_message "${RED}Failed to download catalog${NC}"
        exit 1
    fi
    
    # Skip header line and process each book
    tail -n +2 "$catalog_file" | while IFS=, read -r id title author subject; do
        for topic in "${!TOPICS[@]}"; do
            if echo "$subject $title" | grep -iE "${TOPICS[$topic]}" > /dev/null; then
                log_message "${YELLOW}Processing: $title${NC}"
                download_book "$id" "$title" "$topic"
                break
            fi
        done
    done
}

# Main function
main() {
    # Get sudo privileges at the start
    get_sudo
    
    log_message "${YELLOW}Starting Gutenberg download process...${NC}"
    
    # Create necessary directories
    setup_directories
    
    # Initialize catalog file
    echo "ID,Title,Topic,Filename,Date_Added" > "$CATALOG_FILE"
    
    # Process catalog and download books
    process_catalog
    
    log_message "${GREEN}Download process complete${NC}"
    log_message "Books have been saved to: $STORAGE_DIR"
}

# Run main process
main 