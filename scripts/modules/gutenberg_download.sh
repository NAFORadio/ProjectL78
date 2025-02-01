#!/bin/bash

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
STORAGE_DIR="/Users/jason/Desktop/Share Files/Gutenberg_Library"
LOG_FILE="$STORAGE_DIR/logs/gutenberg_download.log"
CATALOG_FILE="$STORAGE_DIR/catalog.csv"

# Topics of interest
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
)

# Create necessary directories
setup_directories() {
    mkdir -p "$STORAGE_DIR"/{logs,books,catalog}
    for topic in "${!TOPICS[@]}"; do
        mkdir -p "$STORAGE_DIR/books/$topic"
    done
}

# Initialize catalog
create_catalog() {
    echo "ID,Title,Author,Topic,Path,Date_Added" > "$CATALOG_FILE"
}

# Download and parse RDF catalog
download_catalog() {
    echo -e "${YELLOW}Downloading Gutenberg catalog...${NC}"
    wget -q -O "$STORAGE_DIR/catalog/catalog.rdf.zip" "https://www.gutenberg.org/cache/epub/feeds/rdf-files.tar.zip"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to download catalog${NC}"
        exit 1
    fi
    
    unzip -q -o "$STORAGE_DIR/catalog/catalog.rdf.zip" -d "$STORAGE_DIR/catalog/"
}

# Parse book metadata and check against topics
process_book() {
    local rdf_file="$1"
    local book_id=$(grep -o "ebooks/[0-9]*" "$rdf_file" | head -1 | cut -d'/' -f2)
    local title=$(grep -o "<dcterms:title>.*</dcterms:title>" "$rdf_file" | sed 's/<[^>]*>//g')
    local author=$(grep -o "<pgterms:name>.*</pgterms:name>" "$rdf_file" | sed 's/<[^>]*>//g')
    local subject=$(grep -o "<dcterms:subject>.*</dcterms:subject>" "$rdf_file" | sed 's/<[^>]*>//g')
    
    for topic in "${!TOPICS[@]}"; do
        if echo "$subject $title" | grep -iE "${TOPICS[$topic]}" > /dev/null; then
            echo "$book_id|$title|$author|$topic"
            return 0
        fi
    done
    return 1
}

# Download a specific book
download_book() {
    local book_id="$1"
    local title="$2"
    local author="$3"
    local topic="$4"
    
    local output_dir="$STORAGE_DIR/books/$topic"
    local filename="${book_id}_${title// /_}"
    
    echo -e "${YELLOW}Downloading: $title${NC}"
    
    # Try different formats in order of preference
    for format in pdf epub.noimages txt; do
        wget -q -O "$output_dir/$filename.$format" "https://www.gutenberg.org/ebooks/$book_id.${format}"
        if [ $? -eq 0 ] && [ -s "$output_dir/$filename.$format" ]; then
            echo "$book_id,$title,$author,$topic,$filename.$format,$(date '+%Y-%m-%d')" >> "$CATALOG_FILE"
            echo -e "${GREEN}Successfully downloaded: $filename.$format${NC}"
            return 0
        fi
    done
    
    echo -e "${RED}Failed to download: $title${NC}"
    return 1
}

# Main function
main() {
    echo -e "${YELLOW}NAFO Radio Gutenberg Knowledge Acquisition Tool${NC}"
    echo -e "${YELLOW}Focused Topics Version${NC}"
    
    setup_directories
    create_catalog
    download_catalog
    
    echo -e "${YELLOW}Processing catalog for relevant books...${NC}"
    
    find "$STORAGE_DIR/catalog" -name "*.rdf" | while read rdf_file; do
        book_info=$(process_book "$rdf_file")
        if [ $? -eq 0 ]; then
            IFS='|' read -r book_id title author topic <<< "$book_info"
            download_book "$book_id" "$title" "$author" "$topic"
        fi
    done
    
    echo -e "${GREEN}Download complete!${NC}"
    echo -e "Books have been saved to: $STORAGE_DIR"
}

# Run main process
main 