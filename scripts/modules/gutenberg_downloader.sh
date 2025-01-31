#!/bin/bash
# Mass downloader for Project Gutenberg library

source "$(dirname "$0")/../common/utils.sh"

CATALOG_URL="https://www.gutenberg.org/cache/epub/feeds/rdf-files.tar.bz2"
CATALOG_DIR="${STORAGE_ROOT}/library/.catalog"
BOOKS_DIR="${STORAGE_ROOT}/library/gutenberg"
FAILED_LOG="${STORAGE_ROOT}/library/failed_downloads.log"
PROGRESS_FILE="${STORAGE_ROOT}/library/download_progress.log"

setup_download_environment() {
    log_message "Setting up download environment..."
    mkdir -p "$CATALOG_DIR" "$BOOKS_DIR"
    touch "$FAILED_LOG" "$PROGRESS_FILE"
}

fetch_catalog() {
    log_message "Downloading Project Gutenberg catalog..."
    wget -q "$CATALOG_URL" -O "${CATALOG_DIR}/catalog.tar.bz2"
    
    cd "$CATALOG_DIR"
    tar xjf catalog.tar.bz2
    
    # Extract all book IDs from RDF files
    find . -name "pg*.rdf" -exec grep -h '<dcterms:identifier>Project Gutenberg' {} \; | \
        grep -o '[0-9]\+' | sort -n > book_ids.txt
    
    log_message "${GREEN}Found $(wc -l < book_ids.txt) books in catalog${NC}"
}

download_book() {
    local book_id=$1
    local output_dir="$BOOKS_DIR"
    local success=0
    
    # Skip if already downloaded successfully
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
        if wget --timeout=30 --tries=3 -q -O "${output_dir}/${book_id}.txt" "$url"; then
            if [ -s "${output_dir}/${book_id}.txt" ]; then
                echo "${book_id}:SUCCESS:$(date +%s)" >> "$PROGRESS_FILE"
                log_message "${GREEN}Successfully downloaded book ${book_id}${NC}"
                success=1
                break
            fi
        fi
    done
    
    if [ $success -eq 0 ]; then
        echo "${book_id}:FAILED:$(date +%s)" >> "$FAILED_LOG"
        log_message "${RED}Failed to download book ${book_id}${NC}"
        return 1
    fi
}

download_all_books() {
    local total_books=$(wc -l < "${CATALOG_DIR}/book_ids.txt")
    local current=0
    local success=0
    local failed=0
    
    log_message "Starting download of all Project Gutenberg books..."
    log_message "Total books to process: $total_books"
    
    while read -r book_id; do
        current=$((current + 1))
        
        # Show progress
        if [ $((current % 10)) -eq 0 ]; then
            log_message "Progress: ${current}/${total_books} ($(( (current * 100) / total_books ))%)"
        fi
        
        if download_book "$book_id"; then
            success=$((success + 1))
        else
            failed=$((failed + 1))
        fi
        
        # Rate limiting - be nice to Gutenberg servers
        sleep 2
        
        # Save checkpoint every 100 books
        if [ $((current % 100)) -eq 0 ]; then
            log_message "Checkpoint - Success: $success, Failed: $failed"
        fi
        
    done < "${CATALOG_DIR}/book_ids.txt"
    
    log_message "${GREEN}Download complete!${NC}"
    log_message "Total processed: $current"
    log_message "Successfully downloaded: $success"
    log_message "Failed downloads: $failed"
}

resume_downloads() {
    log_message "Resuming previous download session..."
    
    # Get list of failed or not yet downloaded books
    comm -23 \
        <(sort "${CATALOG_DIR}/book_ids.txt") \
        <(grep SUCCESS "$PROGRESS_FILE" | cut -d: -f1 | sort) \
        > "${CATALOG_DIR}/remaining_books.txt"
    
    mv "${CATALOG_DIR}/remaining_books.txt" "${CATALOG_DIR}/book_ids.txt"
    download_all_books
}

main() {
    setup_download_environment
    
    # Check if we have a catalog
    if [ ! -f "${CATALOG_DIR}/book_ids.txt" ]; then
        fetch_catalog
    fi
    
    # Check if we have a progress file
    if [ -f "$PROGRESS_FILE" ]; then
        read -p "Previous download session found. Resume? (y/n) " answer
        if [[ $answer =~ ^[Yy]$ ]]; then
            resume_downloads
        else
            download_all_books
        fi
    else
        download_all_books
    fi
}

# Run the script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi 