#!/bin/bash
# Gutenberg Library Downloader for Offline Use
# Based on: https://www.gutenberg.org/ebooks/offline_catalogs.html

source "$(dirname "$0")/../common/utils.sh"

# Configuration
STORAGE_ROOT="${STORAGE_ROOT:-/storage}"
LIBRARY_DIR="${STORAGE_ROOT}/library"
CATALOG_DIR="${LIBRARY_DIR}/catalog"
BOOKS_DIR="${LIBRARY_DIR}/books"
METADATA_DIR="${LIBRARY_DIR}/metadata"
FAILED_LOG="${LIBRARY_DIR}/failed_downloads.log"
PROGRESS_FILE="${LIBRARY_DIR}/download_progress.log"

# Catalog URLs for compressed files
CATALOG_URLS=(
    "https://www.gutenberg.org/cache/epub/feeds/rdf-files.tar.bz2"
    "https://www.gutenberg.org/cache/epub/feeds/pg_catalog.csv"
    "https://www.gutenberg.org/dirs/GUTINDEX.ALL"
)

# Download settings
MAX_PARALLEL=5

setup_environment() {
    mkdir -p "$CATALOG_DIR" "$BOOKS_DIR" "$METADATA_DIR"
}

fetch_catalog() {
    log_message "Downloading Project Gutenberg catalogs..."
    
    # Download and extract RDF catalog
    log_message "Downloading RDF catalog..."
    wget -q "${CATALOG_URLS[0]}" -O "${CATALOG_DIR}/rdf-files.tar.bz2" || {
        log_message "${RED}Failed to download RDF catalog${NC}"
        return 1
    }
    
    cd "$CATALOG_DIR" || return 1
    tar xjf rdf-files.tar.bz2 || {
        log_message "${RED}Failed to extract RDF catalog${NC}"
        return 1
    }
    
    # Extract book IDs and URLs from RDF files
    log_message "Processing RDF files..."
    find . -name "pg*.rdf" -exec grep -H '<dcterms:hasFormat.*txt\.gz' {} \; | \
        sed -n 's/.*\(https:\/\/[^"]*\.txt\.gz\).*/\1/p' > "${CATALOG_DIR}/txt_urls.txt"
    
    # Get book IDs
    cut -d'/' -f5 "${CATALOG_DIR}/txt_urls.txt" | sort -u > "${CATALOG_DIR}/book_ids.txt"
    
    # Process metadata
    log_message "Processing metadata..."
    while read -r rdf_file; do
        book_id=$(basename "$rdf_file" .rdf | sed 's/pg//')
        title=$(grep -o '<dcterms:title>[^<]*' "$rdf_file" | cut -d'>' -f2-)
        author=$(grep -o '<dcterms:creator>[^<]*' "$rdf_file" | cut -d'>' -f2-)
        language=$(grep -o '<dcterms:language>[^<]*' "$rdf_file" | cut -d'>' -f2-)
        
        echo "{\"id\":\"$book_id\",\"title\":\"$title\",\"author\":\"$author\",\"language\":\"$language\"}" \
            > "${METADATA_DIR}/${book_id}.json"
    done < <(find . -name "pg*.rdf")
    
    local total_books=$(wc -l < "${CATALOG_DIR}/book_ids.txt" || echo 0)
    if [ "$total_books" -eq 0 ]; then
        log_message "${RED}No books found in catalog. Check network connection and try again.${NC}"
        return 1
    fi
    
    log_message "${GREEN}Found $total_books books with compressed text files${NC}"
    return 0
}

download_book() {
    local book_id=$1
    local output_dir="$BOOKS_DIR"
    
    # Skip if already downloaded
    if [ -f "${output_dir}/${book_id}.txt.gz" ]; then
        return 0
    fi
    
    # Get URL for this book
    local url=$(grep "/${book_id}/" "${CATALOG_DIR}/txt_urls.txt" | head -1)
    if [ -z "$url" ]; then
        echo "${book_id}:FAILED:NO_URL:$(date +%s)" >> "$FAILED_LOG"
        return 1
    fi
    
    # Download compressed file directly
    if wget --timeout=30 --tries=3 -q "$url" -O "${output_dir}/${book_id}.txt.gz"; then
        if verify_compressed_file "${output_dir}/${book_id}.txt.gz"; then
            echo "${book_id}:SUCCESS:$(date +%s)" >> "$PROGRESS_FILE"
            return 0
        else
            rm -f "${output_dir}/${book_id}.txt.gz"
        fi
    fi
    
    echo "${book_id}:FAILED:DOWNLOAD:$(date +%s)" >> "$FAILED_LOG"
    return 1
}

verify_compressed_file() {
    local file="$1"
    
    # Check if file exists and is not empty
    if [ ! -s "$file" ]; then
        return 1
    fi
    
    # Try to read the compressed file
    if ! gzip -t "$file" 2>/dev/null; then
        return 1
    fi
    
    # Check content (first few lines should contain "Project Gutenberg")
    if ! zcat "$file" 2>/dev/null | head -n 100 | grep -q "Project Gutenberg"; then
        return 1
    fi
    
    return 0
}

download_all() {
    local total_books=$(wc -l < "${CATALOG_DIR}/book_ids.txt" || echo 0)
    
    if [ "$total_books" -eq 0 ]; then
        log_message "${RED}No books found to download${NC}"
        return 1
    fi
    
    log_message "Starting download of $total_books compressed books..."
    
    local completed=0
    local failed=0
    
    while read -r book_id; do
        download_book "$book_id" &
        
        # Limit parallel downloads
        while [ $(jobs -r | wc -l) -ge $MAX_PARALLEL ]; do
            wait -n
        done
        
        # Update progress
        completed=$((completed + 1))
        if [ $((completed % 100)) -eq 0 ]; then
            local progress=$((completed * 100 / total_books))
            log_message "Progress: $completed/$total_books ($progress%)"
        fi
    done < "${CATALOG_DIR}/book_ids.txt"
    
    wait
    
    failed=$(wc -l < "$FAILED_LOG")
    log_message "${GREEN}Download complete${NC}"
    log_message "Total books: $total_books"
    log_message "Failed: $failed"
    log_message "Success rate: $(( (total_books - failed) * 100 / total_books ))%"
}

main() {
    setup_environment || exit 1
    
    if [ ! -f "${CATALOG_DIR}/txt_urls.txt" ]; then
        fetch_catalog || exit 1
    fi
    
    # Handle resume
    if [ -f "$PROGRESS_FILE" ]; then
        local total_downloaded=$(grep -c SUCCESS "$PROGRESS_FILE" || echo 0)
        local total_books=$(wc -l < "${CATALOG_DIR}/book_ids.txt" || echo 0)
        
        if [ "$total_books" -gt 0 ]; then
            local percent_done=$(( (total_downloaded * 100) / total_books ))
            log_message "Previous download session found:"
            log_message "Progress: $total_downloaded/$total_books ($percent_done%)"
            read -p "Resume download? (y/n) " answer
            
            if [[ $answer =~ ^[Yy]$ ]]; then
                comm -23 \
                    <(sort "${CATALOG_DIR}/book_ids.txt") \
                    <(grep SUCCESS "$PROGRESS_FILE" | cut -d: -f1 | sort) \
                    > "${CATALOG_DIR}/remaining_books.txt"
                mv "${CATALOG_DIR}/remaining_books.txt" "${CATALOG_DIR}/book_ids.txt"
            fi
        else
            log_message "${RED}No books found in catalog. Running full download...${NC}"
            fetch_catalog || exit 1
        fi
    fi
    
    download_all
    
    if [ -f "${SCRIPT_DIR}/modules/webui.sh" ]; then
        source "${SCRIPT_DIR}/modules/webui.sh"
        setup_gutenberg_browser 8080
        log_message "${GREEN}Web interface available at http://localhost:8080${NC}"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi 