#!/bin/bash
# Gutenberg Library Downloader for Offline Use
# Downloads complete text archive from gutenberg.org/cache/epub/feeds/

source "$(dirname "$0")/../common/utils.sh"

# Configuration
STORAGE_ROOT="${STORAGE_ROOT:-/storage}"
LIBRARY_DIR="${STORAGE_ROOT}/library"
CATALOG_DIR="${LIBRARY_DIR}/catalog"
BOOKS_DIR="${LIBRARY_DIR}/books"
METADATA_DIR="${LIBRARY_DIR}/metadata"
TEMP_DIR="${LIBRARY_DIR}/temp"

# Direct archive URL (9.8GB compressed)
ARCHIVE_URL="https://www.gutenberg.org/cache/epub/feeds/txt-files.tar.zip"
CATALOG_CSV="https://www.gutenberg.org/cache/epub/feeds/pg_catalog.csv"

setup_environment() {
    mkdir -p "$CATALOG_DIR" "$BOOKS_DIR" "$METADATA_DIR" "$TEMP_DIR"
}

download_archive() {
    log_message "Downloading Project Gutenberg text archive..."
    
    # Download with progress and resume capability
    wget --progress=bar:force:noscroll \
         --continue \
         --tries=0 \
         "$ARCHIVE_URL" \
         -O "${TEMP_DIR}/txt-files.tar.zip" || {
        log_message "${RED}Failed to download archive${NC}"
        return 1
    }
    
    # Download catalog
    wget -q "$CATALOG_CSV" -O "${CATALOG_DIR}/catalog.csv" || {
        log_message "${RED}Failed to download catalog${NC}"
        return 1
    }
}

extract_and_organize() {
    log_message "Extracting archive..."
    
    cd "$TEMP_DIR" || return 1
    
    # Extract with progress feedback
    unzip -q txt-files.tar.zip || {
        log_message "${RED}Failed to extract zip archive${NC}"
        return 1
    }
    
    log_message "Extracting tar archive..."
    tar xf txt-files.tar || {
        log_message "${RED}Failed to extract tar archive${NC}"
        return 1
    }
    
    # Organize books by category using catalog
    log_message "Organizing books..."
    
    # Create category structure
    mkdir -p "${BOOKS_DIR}"/{fiction,nonfiction,reference,philosophy,science,history}
    
    # Process catalog and organize books
    tail -n +2 "${CATALOG_DIR}/catalog.csv" | while IFS=, read -r id title author language year subject; do
        # Find the text file
        book_file=$(find . -name "${id}.txt" -o -name "pg${id}.txt" | head -1)
        if [ -n "$book_file" ]; then
            # Determine category based on subject
            category="other"
            case "$subject" in
                *Fiction*) category="fiction" ;;
                *Philosophy*) category="philosophy" ;;
                *Science*) category="science" ;;
                *History*) category="history" ;;
                *Reference*) category="reference" ;;
                *) category="nonfiction" ;;
            esac
            
            # Create category subdirectory if needed
            target_dir="${BOOKS_DIR}/${category}"
            mkdir -p "$target_dir"
            
            # Move and compress the book
            gzip -c "$book_file" > "${target_dir}/${id}.txt.gz"
            
            # Save metadata
            echo "{\"id\":\"$id\",\"title\":\"$title\",\"author\":\"$author\",\"language\":\"$language\",\"year\":\"$year\",\"category\":\"$category\"}" \
                > "${METADATA_DIR}/${id}.json"
        fi
    done
    
    # Cleanup
    cd "$LIBRARY_DIR"
    rm -rf "$TEMP_DIR"
    
    log_message "${GREEN}Books organized successfully${NC}"
}

main() {
    setup_environment || exit 1
    
    if [ ! -f "${BOOKS_DIR}/.complete" ]; then
        download_archive || exit 1
        extract_and_organize || exit 1
        touch "${BOOKS_DIR}/.complete"
    else
        log_message "Library already downloaded and organized"
    fi
    
    # Start web interface if available
    if [ -f "${SCRIPT_DIR}/modules/webui.sh" ]; then
        source "${SCRIPT_DIR}/modules/webui.sh"
        setup_gutenberg_browser 8080
        log_message "${GREEN}Web interface available at http://localhost:8080${NC}"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi 