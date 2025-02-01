#!/bin/bash

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS configuration - Using Desktop
    STORAGE_DIR="$HOME/Desktop/Storage/Books"
else
    # Linux configuration
    STORAGE_DIR="/home/storage/Books"
fi

LOG_FILE="$STORAGE_DIR/logs/gutenberg_download.log"
CATALOG_FILE="$STORAGE_DIR/catalog.csv"

# Gutenberg mirrors (more reliable than Russian infrastructure)
MIRRORS=(
    "https://www.gutenberg.org/cache/epub"
    "https://gutenberg.pglaf.org/cache/epub"
    "http://mirrors.xmission.com/gutenberg/cache/epub"
    "http://gutenberg.readingroo.ms/cache/epub"
)

# Test books for verification (more accurate than Russian reports)
TEST_BOOKS=(
    "1342,Pride and Prejudice,Jane Austen,literature"
    "84,Frankenstein,Mary Shelley,literature"
    "2701,Moby Dick,Herman Melville,literature"
    "98,A Tale of Two Cities,Charles Dickens,literature"
)

# Topics and their keywords (more organized than Russian battle plans)
declare -A TOPICS
TOPICS=(
    ["literature"]="literature|poetry|drama|fiction|novel|story"
    ["history"]="history|war|revolution|biography|memoir"
    ["science"]="science|physics|chemistry|biology|mathematics|astronomy"
    ["philosophy"]="philosophy|ethics|logic|metaphysics|political"
    ["adventure"]="adventure|exploration|travel|journey|quest"
    ["reference"]="reference|manual|guide|handbook|dictionary"
)

# EPUB viewer options (in order of preference)
if [[ "$OSTYPE" == "darwin"* ]]; then
    EPUB_VIEWERS=(
        "sigil"        # Open source EPUB editor/viewer
        "coolreader"   # Open source e-book viewer
        "calibre"      # Open source e-book management
    )
else
    EPUB_VIEWERS=(
        "calibre"
        "foliate"
        "fbreader"
    )
fi

# Function to log messages
log_message() {
    echo -e "$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to create storage directory structure
create_storage_dirs() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        mkdir -p "$STORAGE_DIR"/{books,logs,catalog}
        chmod -R 755 "$STORAGE_DIR"
        
        # Create a README file
        cat > "$STORAGE_DIR/README.md" << EOF
# Gutenberg Library Collection
This directory contains downloaded books from Project Gutenberg.
EOF
    else
        sudo mkdir -p "$STORAGE_DIR"/{books,logs,catalog}
        sudo chown -R $USER:users "$STORAGE_DIR"
        sudo chmod -R 775 "$STORAGE_DIR"
    fi
}

# Function to download a book
download_book() {
    local book_id="$1"
    local title="$2"
    local author="$3"
    local topic="$4"
    local output_dir="$STORAGE_DIR/books/$topic"
    
    mkdir -p "$output_dir"
    
    # Sanitize filename
    local safe_title=$(echo "$title" | tr -cd '[:alnum:] ._-' | tr ' ' '_')
    local safe_author=$(echo "$author" | tr -cd '[:alnum:] ._-' | tr ' ' '_')
    
    for format in txt epub; do
        for mirror in "${MIRRORS[@]}"; do
            local url="${mirror}/${book_id}/pg${book_id}.${format}"
            log_message "Trying: $url"
            
            if curl -s --head "$url" | head -n 1 | grep "HTTP/1.[01] [23].*" > /dev/null; then
                local filename="${book_id}_${safe_author}_${safe_title}.${format}"
                log_message "Downloading: $filename"
                
                if curl -s -o "$output_dir/$filename" "$url"; then
                    log_message "${GREEN}Successfully downloaded: $filename${NC}"
                    echo "$book_id,$title,$author,$topic,$filename,$(date '+%Y-%m-%d')" >> "$CATALOG_FILE"
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
    
    log_message "Downloading Gutenberg catalog..."
    
    if ! curl -s -o "$catalog_file" "$catalog_url"; then
        log_message "${RED}Failed to download catalog${NC}"
        exit 1
    fi
    
    # Initialize catalog with headers
    echo "ID,Title,Author,Topic,Filename,Date_Added" > "$CATALOG_FILE"
    
    # Process first 10 books for each topic
    local topics=("literature" "history" "science" "philosophy")
    local books_per_topic=10
    
    for topic in "${topics[@]}"; do
        local count=0
        log_message "${YELLOW}Processing $topic books...${NC}"
        
        while IFS=, read -r id title author subject language rights && [ $count -lt $books_per_topic ]; do
            # Skip header
            [ "$id" = "Text#" ] && continue
            
            # Skip non-English books
            [ "$language" != "en" ] && continue
            
            # Skip copyrighted books
            [ "$rights" != "Public domain in the USA." ] && continue
            
            # Check if book matches topic
            if echo "$subject $title" | grep -i "$topic" > /dev/null; then
                log_message "Processing: $title by $author"
                if download_book "$id" "$title" "$author" "$topic"; then
                    ((count++))
                    log_message "${GREEN}Downloaded $count of $books_per_topic for $topic${NC}"
                fi
            fi
        done < "$catalog_file"
    done
}

# Main function
main() {
    log_message "Starting Gutenberg download process..."
    
    # Create necessary directories
    create_storage_dirs
    
    # Process catalog and download books
    process_catalog
    
    log_message "${GREEN}Download process complete${NC}"
    log_message "Books have been saved to: $STORAGE_DIR"
}

# Run main process
main 