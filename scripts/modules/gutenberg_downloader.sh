#!/bin/bash
# Gutenberg Library Mass Downloader

source "$(dirname "$0")/../common/utils.sh"

# Configuration
STORAGE_ROOT="${STORAGE_ROOT:-/storage}"
BOOKS_DIR="${STORAGE_ROOT}/library/gutenberg"
CATALOG_DIR="${STORAGE_ROOT}/library/.catalog"
METADATA_DIR="${STORAGE_ROOT}/library/.metadata"
PROGRESS_FILE="${STORAGE_ROOT}/library/download_progress.log"
FAILED_LOG="${STORAGE_ROOT}/library/failed_downloads.log"
MAX_PARALLEL=5
RATE_LIMIT="500k"  # Limit download speed to be nice to Gutenberg

setup_environment() {
    mkdir -p "$BOOKS_DIR" "$CATALOG_DIR" "$METADATA_DIR"
    touch "$PROGRESS_FILE" "$FAILED_LOG"
}

fetch_catalog() {
    log_message "Downloading Project Gutenberg catalog..."
    wget -q "https://www.gutenberg.org/cache/epub/feeds/rdf-files.tar.bz2" -O "${CATALOG_DIR}/catalog.tar.bz2"
    
    cd "$CATALOG_DIR"
    tar xjf catalog.tar.bz2
    
    # Extract all book IDs
    find . -name "pg*.rdf" -exec grep -h '<dcterms:identifier>Project Gutenberg' {} \; | \
        grep -o '[0-9]\+' | sort -n > book_ids.txt
    
    log_message "${GREEN}Found $(wc -l < book_ids.txt) books in catalog${NC}"
}

download_book() {
    local book_id=$1
    local output_dir="$BOOKS_DIR"
    local retry_count=0
    local max_retries=3
    
    # Skip if already downloaded
    if grep -q "^$book_id:SUCCESS" "$PROGRESS_FILE"; then
        return 0
    fi
    
    # Try different URL formats
    local urls=(
        "https://www.gutenberg.org/cache/epub/${book_id}/pg${book_id}.txt"
        "https://www.gutenberg.org/files/${book_id}/${book_id}.txt"
        "https://www.gutenberg.org/files/${book_id}/${book_id}-0.txt"
        "https://www.gutenberg.org/ebooks/${book_id}.txt.utf-8"
    )
    
    for url in "${urls[@]}"; do
        if wget --limit-rate="$RATE_LIMIT" --timeout=30 --tries=3 -q -O "${output_dir}/${book_id}.txt" "$url"; then
            if [ -s "${output_dir}/${book_id}.txt" ]; then
                echo "${book_id}:SUCCESS:$(date +%s)" >> "$PROGRESS_FILE"
                return 0
            fi
        fi
        sleep 1  # Be nice to the server
    done
    
    echo "${book_id}:FAILED:$(date +%s)" >> "$FAILED_LOG"
    return 1
}

download_all() {
    local total_books=$(wc -l < "${CATALOG_DIR}/book_ids.txt")
    log_message "Starting download of $total_books books..."
    
    # Use GNU Parallel for parallel downloads
    cat "${CATALOG_DIR}/book_ids.txt" | \
        parallel --progress --jobs "$MAX_PARALLEL" \
        --joblog "${STORAGE_ROOT}/library/parallel.log" \
        download_book {}
}

main() {
    setup_environment
    
    if [ ! -f "${CATALOG_DIR}/book_ids.txt" ]; then
        fetch_catalog
    fi
    
    if [ -f "$PROGRESS_FILE" ]; then
        read -p "Previous download session found. Resume? (y/n) " answer
        if [[ $answer =~ ^[Yy]$ ]]; then
            # Get remaining books
            comm -23 \
                <(sort "${CATALOG_DIR}/book_ids.txt") \
                <(grep SUCCESS "$PROGRESS_FILE" | cut -d: -f1 | sort) \
                > "${CATALOG_DIR}/remaining_books.txt"
            mv "${CATALOG_DIR}/remaining_books.txt" "${CATALOG_DIR}/book_ids.txt"
        fi
    fi
    
    download_all
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi 