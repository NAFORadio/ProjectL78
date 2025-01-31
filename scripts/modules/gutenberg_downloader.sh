#!/bin/bash
# Enhanced mass downloader for Project Gutenberg library

source "$(dirname "$0")/../common/utils.sh"

CATALOG_URL="https://www.gutenberg.org/cache/epub/feeds/rdf-files.tar.bz2"
CATALOG_DIR="${STORAGE_ROOT}/library/.catalog"
BOOKS_DIR="${STORAGE_ROOT}/library/gutenberg"
FAILED_LOG="${STORAGE_ROOT}/library/failed_downloads.log"
PROGRESS_FILE="${STORAGE_ROOT}/library/download_progress.log"
METADATA_DIR="${STORAGE_ROOT}/library/.metadata"
MAX_PARALLEL_DOWNLOADS=5
RETRY_DELAY=30
MAX_RETRIES=3

# Error handling
set -eE
trap 'handle_error $? $LINENO $BASH_LINENO "$BASH_COMMAND" $(printf "::%s" ${FUNCNAME[@]:-})' ERR

handle_error() {
    local exit_code=$1
    local line_no=$2
    local bash_lineno=$3
    local last_command=$4
    local func_trace=$5
    
    log_message "${RED}Error occurred in download process${NC}"
    log_message "Exit code: $exit_code"
    log_message "Line number: $line_no"
    log_message "Command: $last_command"
    log_message "Function trace: $func_trace"
    
    # Save error details
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Error: $exit_code:$line_no:$last_command" >> "${STORAGE_ROOT}/library/error.log"
    
    # Cleanup any partial downloads
    cleanup_partial_downloads
}

cleanup_partial_downloads() {
    find "$BOOKS_DIR" -type f -size 0 -delete
    find "$BOOKS_DIR" -type f -name "*.part" -delete
}

setup_download_environment() {
    log_message "Setting up download environment..."
    mkdir -p "$CATALOG_DIR" "$BOOKS_DIR" "$METADATA_DIR"
    touch "$FAILED_LOG" "$PROGRESS_FILE"
    
    # Install required tools
    apt-get update && apt-get install -y \
        parallel \
        xmlstarlet \
        jq \
        python3-beautifulsoup4
}

fetch_catalog() {
    log_message "Downloading Project Gutenberg catalog..."
    wget -q "$CATALOG_URL" -O "${CATALOG_DIR}/catalog.tar.bz2"
    
    cd "$CATALOG_DIR"
    tar xjf catalog.tar.bz2
    
    # Extract metadata and book IDs
    python3 - << 'EOF' > "${CATALOG_DIR}/metadata.json"
from bs4 import BeautifulSoup
import json
import glob
import os

def extract_metadata(rdf_file):
    with open(rdf_file, 'r', encoding='utf-8') as f:
        soup = BeautifulSoup(f.read(), 'xml')
        
    metadata = {
        'id': soup.find('pgterms:ebook').get('rdf:about').split('/')[-1],
        'title': soup.find('dcterms:title').text if soup.find('dcterms:title') else 'Unknown',
        'creator': [c.text for c in soup.find_all('pgterms:name')],
        'subjects': [s.text for s in soup.find_all('dcterms:subject')],
        'language': [l.text for l in soup.find_all('dcterms:language')],
        'rights': soup.find('dcterms:rights').text if soup.find('dcterms:rights') else 'Unknown'
    }
    return metadata

metadata_list = []
for rdf_file in glob.glob('cache/epub/*/pg*.rdf'):
    try:
        metadata = extract_metadata(rdf_file)
        metadata_list.append(metadata)
    except Exception as e:
        print(f"Error processing {rdf_file}: {e}", file=sys.stderr)

json.dump(metadata_list, open('metadata.json', 'w'), indent=2)
EOF
    
    # Create book ID list
    jq -r '.[].id' "${CATALOG_DIR}/metadata.json" | sort -n > book_ids.txt
    
    log_message "${GREEN}Found $(wc -l < book_ids.txt) books in catalog${NC}"
}

download_book() {
    local book_id=$1
    local output_dir="$BOOKS_DIR"
    local metadata_file="${METADATA_DIR}/${book_id}.json"
    local success=0
    local retry_count=0
    
    # Skip if already downloaded successfully
    if grep -q "^$book_id:SUCCESS" "$PROGRESS_FILE"; then
        return 0
    fi
    
    # Extract metadata for this book
    jq ".[] | select(.id == \"$book_id\")" "${CATALOG_DIR}/metadata.json" > "$metadata_file"
    
    # Create category directories based on subjects
    local categories=$(jq -r '.subjects[]' "$metadata_file" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
    for category in $categories; do
        mkdir -p "${output_dir}/${category}"
    done
    
    while [ $retry_count -lt $MAX_RETRIES ] && [ $success -eq 0 ]; do
        # Try different URL formats
        local urls=(
            "https://www.gutenberg.org/cache/epub/${book_id}/pg${book_id}.txt"
            "https://www.gutenberg.org/files/${book_id}/${book_id}.txt"
            "https://www.gutenberg.org/files/${book_id}/${book_id}-0.txt"
            "https://www.gutenberg.org/ebooks/${book_id}.txt.utf-8"
        )
        
        for url in "${urls[@]}"; do
            if wget --timeout=30 --tries=3 -q -O "${output_dir}/${book_id}.txt.part" "$url"; then
                if [ -s "${output_dir}/${book_id}.txt.part" ]; then
                    mv "${output_dir}/${book_id}.txt.part" "${output_dir}/${book_id}.txt"
                    
                    # Create symlinks in category directories
                    for category in $categories; do
                        ln -sf "../${book_id}.txt" "${output_dir}/${category}/${book_id}.txt"
                    done
                    
                    echo "${book_id}:SUCCESS:$(date +%s)" >> "$PROGRESS_FILE"
                    log_message "${GREEN}Successfully downloaded book ${book_id}${NC}"
                    success=1
                    break
                fi
            fi
        done
        
        if [ $success -eq 0 ]; then
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $MAX_RETRIES ]; then
                log_message "${YELLOW}Retry $retry_count for book ${book_id}${NC}"
                sleep $RETRY_DELAY
            fi
        fi
    done
    
    if [ $success -eq 0 ]; then
        echo "${book_id}:FAILED:$(date +%s):ATTEMPTS=${retry_count}" >> "$FAILED_LOG"
        log_message "${RED}Failed to download book ${book_id} after ${retry_count} attempts${NC}"
        return 1
    fi
}

download_all_books() {
    local total_books=$(wc -l < "${CATALOG_DIR}/book_ids.txt")
    log_message "Starting parallel download of all Project Gutenberg books..."
    log_message "Total books to process: $total_books"
    
    # Use GNU Parallel for downloads
    cat "${CATALOG_DIR}/book_ids.txt" | \
        parallel --progress --jobs $MAX_PARALLEL_DOWNLOADS \
        --joblog "${STORAGE_ROOT}/library/parallel.log" \
        download_book {}
    
    # Generate download report
    generate_report
}

generate_report() {
    local total_books=$(wc -l < "${CATALOG_DIR}/book_ids.txt")
    local successful=$(grep SUCCESS "$PROGRESS_FILE" | wc -l)
    local failed=$(grep FAILED "$FAILED_LOG" | wc -l)
    
    log_message "Download Report:"
    log_message "Total books: $total_books"
    log_message "Successfully downloaded: $successful"
    log_message "Failed downloads: $failed"
    log_message "Success rate: $(( (successful * 100) / total_books ))%"
    
    # Generate detailed report
    cat > "${STORAGE_ROOT}/library/download_report.txt" << EOF
Download Report ($(date '+%Y-%m-%d %H:%M:%S'))
================================================
Total books in catalog: $total_books
Successfully downloaded: $successful
Failed downloads: $failed
Success rate: $(( (successful * 100) / total_books ))%

Most common failure reasons:
$(grep FAILED "$FAILED_LOG" | cut -d: -f4 | sort | uniq -c | sort -nr | head -5)

Download duration: $(( ($(date +%s) - $(stat -c %Y "$PROGRESS_FILE")) / 3600 )) hours

Category Statistics:
$(find "$BOOKS_DIR" -type d -mindepth 1 -maxdepth 1 | while read dir; do
    echo "$(basename "$dir"): $(find "$dir" -type f | wc -l) books"
done)
EOF
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