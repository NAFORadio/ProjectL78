#!/bin/bash

source "$(dirname "$0")/../../scripts/common/utils.sh"
source "$(dirname "$0")/../../scripts/modules/gutenberg_downloader.sh"

# Override storage root for testing
STORAGE_ROOT="/tmp/nafo_test"

test_gutenberg_downloader() {
    log_message "Testing Gutenberg mass downloader..."
    
    # Create test environment
    setup_environment
    
    # Create mock catalog with a representative sample
    log_message "Creating mock catalog..."
    mkdir -p "${CATALOG_DIR}/cache/epub"
    
    # Create mock catalog tarball
    cd "${CATALOG_DIR}"
    
    # Create sample RDF files to test different book types
    local test_books=(
        "1"     # First book
        "11"    # Early book
        "1661"  # Mid-range book
        "68001" # Recent book
        "70000" # Very recent book
    )
    
    # Create proper RDF directory structure
    for book_id in "${test_books[@]}"; do
        mkdir -p "${CATALOG_DIR}/cache/epub/${book_id}"
        cat > "${CATALOG_DIR}/pg${book_id}.rdf" << EOF
<?xml version="1.0" encoding="utf-8"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:dcterms="http://purl.org/dc/terms/"
         xmlns:pgterms="http://www.gutenberg.org/2009/pgterms/">
  <pgterms:ebook rdf:about="ebooks/${book_id}">
    <dcterms:title>Test Book ${book_id}</dcterms:title>
    <dcterms:creator>Test Author</dcterms:creator>
    <dcterms:publisher>Project Gutenberg</dcterms:publisher>
    <dcterms:identifier>Project Gutenberg EBook ${book_id}</dcterms:identifier>
    <dcterms:issued>2024</dcterms:issued>
    <dcterms:language>
      <rdf:Description rdf:nodeID="N2">
        <rdf:value rdf:datatype="http://purl.org/dc/terms/RFC4646">en</rdf:value>
      </rdf:Description>
    </dcterms:language>
  </pgterms:ebook>
</rdf:RDF>
EOF
    done
    
    # Create tarball of RDF files
    tar cjf catalog.tar.bz2 pg*.rdf
    
    # Override fetch_catalog function for testing
    fetch_catalog() {
        log_message "Processing mock catalog..."
        cd "${CATALOG_DIR}"
        
        # Extract book IDs from RDF files
        find . -name "pg*.rdf" -exec grep -h '<dcterms:identifier>Project Gutenberg' {} \; | \
            grep -o '[0-9]\+' | sort -n > book_ids.txt
        
        log_message "${GREEN}Found $(wc -l < book_ids.txt) books in catalog${NC}"
    }
    
    # Test catalog creation
    log_message "Testing catalog creation..."
    fetch_catalog
    
    # Verify book IDs were extracted
    if [ ! -f "${CATALOG_DIR}/book_ids.txt" ]; then
        log_message "${RED}Failed to create book_ids.txt${NC}"
        return 1
    fi
    
    local found_books=$(wc -l < "${CATALOG_DIR}/book_ids.txt")
    if [ "$found_books" -ne "${#test_books[@]}" ]; then
        log_message "${RED}Expected ${#test_books[@]} books, found $found_books${NC}"
        return 1
    fi
    
    # Mock download function for testing
    download_book() {
        local book_id=$1
        local output_dir="$BOOKS_DIR"
        
        # Create a test file with some content
        echo "This is test content for book $book_id" > "${output_dir}/${book_id}.txt"
        echo "${book_id}:SUCCESS:$(date +%s)" >> "$PROGRESS_FILE"
        return 0
    }
    
    # Test parallel download
    log_message "Testing parallel download..."
    download_all
    
    # Verify all books were "downloaded"
    local downloaded=0
    local failed=0
    
    for book_id in "${test_books[@]}"; do
        if [ -f "${BOOKS_DIR}/${book_id}.txt" ] && grep -q "^${book_id}:SUCCESS" "$PROGRESS_FILE"; then
            downloaded=$((downloaded + 1))
        else
            failed=$((failed + 1))
            log_message "${RED}Failed to download book ${book_id}${NC}"
        fi
    done
    
    log_message "Download statistics:"
    log_message "Total books: ${#test_books[@]}"
    log_message "Downloaded: $downloaded"
    log_message "Failed: $failed"
    
    # Test resume functionality
    log_message "Testing resume functionality..."
    
    # Remove one book to simulate incomplete download
    rm -f "${BOOKS_DIR}/${test_books[0]}.txt"
    sed -i "/^${test_books[0]}:SUCCESS/d" "$PROGRESS_FILE"
    
    # Try resume
    if [ -f "$PROGRESS_FILE" ]; then
        # Get remaining books
        comm -23 \
            <(sort "${CATALOG_DIR}/book_ids.txt") \
            <(grep SUCCESS "$PROGRESS_FILE" | cut -d: -f1 | sort) \
            > "${CATALOG_DIR}/remaining_books.txt"
        mv "${CATALOG_DIR}/remaining_books.txt" "${CATALOG_DIR}/book_ids.txt"
    fi
    
    # Download remaining
    download_all
    
    # Verify all books are now present
    local final_count=$(find "$BOOKS_DIR" -type f -name "*.txt" | wc -l)
    if [ "$final_count" -ne "${#test_books[@]}" ]; then
        log_message "${RED}Resume test failed. Expected ${#test_books[@]} books, found $final_count${NC}"
        return 1
    fi
    
    # Test actual download URLs
    log_message "Testing actual download URLs..."
    
    # Restore original download_book function
    unset -f download_book
    source "$(dirname "$0")/../../scripts/modules/gutenberg_downloader.sh"
    
    # Test one real download
    local test_book="1661"  # The Declaration of Independence
    if ! download_book "$test_book"; then
        log_message "${RED}Failed to download real test book${NC}"
        return 1
    fi
    
    # Verify content
    if ! grep -q "Declaration of Independence" "${BOOKS_DIR}/${test_book}.txt" 2>/dev/null; then
        log_message "${RED}Downloaded content verification failed${NC}"
        return 1
    fi
    
    log_message "${GREEN}All Gutenberg downloader tests passed!${NC}"
    return 0
}

# Run the test if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Clean up any previous test data
    rm -rf "$STORAGE_ROOT"
    
    # Run test
    test_gutenberg_downloader
    
    # Clean up
    rm -rf "$STORAGE_ROOT"
fi 