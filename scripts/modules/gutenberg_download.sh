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

# Gutenberg mirrors
MIRRORS=(
    "https://www.gutenberg.org/files"
    "https://gutenberg.pglaf.org/files"
    "http://mirrors.xmission.com/gutenberg/files"
    "http://gutenberg.readingroo.ms/files"
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

# Create necessary directories
setup_directories() {
    mkdir -p "$STORAGE_DIR"/{logs,books,catalog}
    for topic in "${!TOPICS[@]}"; do
        mkdir -p "$STORAGE_DIR/books/$topic"
    done
}

# Try downloading from different mirrors
download_from_mirrors() {
    local book_id="$1"
    local format="$2"
    local output="$3"
    
    for mirror in "${MIRRORS[@]}"; do
        # Try different file patterns
        local urls=(
            "$mirror/$book_id/$book_id.txt"
            "$mirror/$book_id/$book_id-0.txt"
            "$mirror/$book_id/$book_id.pdf"
            "$mirror/$book_id/$book_id-pdf.pdf"
            "$mirror/$book_id/$book_id-h/$book_id-h.htm"
        )
        
        for url in "${urls[@]}"; do
            echo -e "${YELLOW}Trying: $url${NC}"
            if wget --spider "$url" 2>/dev/null; then
                wget -q -O "$output" "$url"
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}Successfully downloaded from: $url${NC}"
                    return 0
                fi
            fi
        done
    done
    return 1
}

# Download catalog
download_catalog() {
    echo -e "${YELLOW}Downloading Gutenberg catalog...${NC}"
    
    # Try to get the catalog from different sources
    local catalog_urls=(
        "https://www.gutenberg.org/cache/epub/feeds/rdf-files.tar.bz2"
        "https://gutenberg.pglaf.org/cache/epub/feeds/rdf-files.tar.bz2"
    )
    
    for url in "${catalog_urls[@]}"; do
        wget -q -O "$STORAGE_DIR/catalog/catalog.tar.bz2" "$url"
        if [ $? -eq 0 ]; then
            tar xjf "$STORAGE_DIR/catalog/catalog.tar.bz2" -C "$STORAGE_DIR/catalog/"
            return 0
        fi
    done
    
    echo -e "${RED}Failed to download catalog${NC}"
    return 1
}

# Process and download books
process_books() {
    echo -e "${YELLOW}Processing books...${NC}"
    local count=0
    
    # Create catalog header
    echo "ID,Title,Author,Topic,Format,Path,Date_Added" > "$CATALOG_FILE"
    
    # Process each RDF file
    find "$STORAGE_DIR/catalog" -name "*.rdf" | while read rdf_file; do
        local book_id=$(grep -o "ebooks/[0-9]*" "$rdf_file" | head -1 | cut -d'/' -f2)
        local title=$(grep -o "<dcterms:title>.*</dcterms:title>" "$rdf_file" | head -1 | sed 's/<[^>]*>//g')
        local author=$(grep -o "<pgterms:name>.*</pgterms:name>" "$rdf_file" | head -1 | sed 's/<[^>]*>//g')
        local subject=$(grep -o "<dcterms:subject>.*</dcterms:subject>" "$rdf_file" | sed 's/<[^>]*>//g')
        
        # Check if book matches our topics
        for topic in "${!TOPICS[@]}"; do
            if echo "$subject $title" | grep -iE "${TOPICS[$topic]}" > /dev/null; then
                count=$((count + 1))
                echo -e "\n${YELLOW}Found matching book ($count):${NC}"
                echo -e "Title: $title"
                echo -e "Author: $author"
                echo -e "Topic: $topic"
                
                local output_dir="$STORAGE_DIR/books/$topic"
                local safe_title=$(echo "$title" | tr -dc '[:alnum:][:space:]' | tr '[:space:]' '_')
                local output_file="$output_dir/${book_id}_${safe_title}"
                
                # Try to download the book
                if download_from_mirrors "$book_id" "txt" "$output_file.txt"; then
                    echo "$book_id,$title,$author,$topic,txt,$output_file.txt,$(date '+%Y-%m-%d')" >> "$CATALOG_FILE"
                fi
            fi
        done
    done
}

# Main function
main() {
    echo -e "${YELLOW}NAFO Radio Gutenberg Knowledge Acquisition Tool${NC}"
    echo -e "${YELLOW}Starting download process...${NC}"
    
    setup_directories
    
    if download_catalog; then
        process_books
        echo -e "${GREEN}Download complete!${NC}"
        echo -e "Books have been saved to: $STORAGE_DIR"
    else
        echo -e "${RED}Failed to download catalog. Exiting.${NC}"
        exit 1
    fi
}

# Run main process
main 