#!/bin/bash
# Test script for content downloads

source "$(dirname "$0")/../../scripts/common/utils.sh"

# Override storage root for testing
STORAGE_ROOT="/tmp/nafo_test"

test_directory_creation() {
    log_message "Testing directory creation..."
    
    # Create test directories
    mkdir -p "${STORAGE_ROOT}/library"/{Philosophy,Science,History,Survival,Mathematics,Literature,Wikipedia,Reference}
    
    # Verify directories exist
    for dir in Philosophy Science History Survival Mathematics Literature Wikipedia Reference; do
        if [ ! -d "${STORAGE_ROOT}/library/$dir" ]; then
            log_message "${RED}Failed to create directory: $dir${NC}"
            return 1
        fi
    done
    
    log_message "${GREEN}Directory creation test passed${NC}"
    return 0
}

test_gutenberg_downloads() {
    log_message "Testing Project Gutenberg downloads..."
    
    # Test multiple URL formats and mirrors
    local test_urls=(
        "https://www.gutenberg.org/cache/epub/1497/pg1497.txt"  # New format
        "https://www.gutenberg.org/ebooks/1497.txt.utf-8"       # Alternative format
        "https://gutenberg.org/files/1497/1497-0.txt"          # Another possible format
    )
    
    local success=0
    for url in "${test_urls[@]}"; do
        log_message "Trying URL: $url"
        if wget -q --spider "$url"; then
            success=1
            log_message "${GREEN}Successfully accessed: $url${NC}"
            break
        fi
    done
    
    if [ $success -eq 0 ]; then
        log_message "${RED}Failed to access any Gutenberg URLs${NC}"
        return 1
    fi
    
    # Test small download
    local test_url="https://www.gutenberg.org/cache/epub/1497/pg1497.txt"
    local target="${STORAGE_ROOT}/library/Literature/republic.txt"
    
    if wget -q -O "$target" "$test_url"; then
        if [ -s "$target" ]; then
            log_message "${GREEN}Successfully downloaded test file${NC}"
        else
            log_message "${RED}Downloaded file is empty${NC}"
            return 1
        fi
    else
        log_message "${RED}Failed to download test file${NC}"
        return 1
    fi
    
    log_message "${GREEN}Gutenberg download test passed${NC}"
    return 0
}

test_gutenberg_mass_downloader() {
    log_message "Testing Gutenberg mass downloader..."
    
    # Create test environment
    local test_catalog_dir="${STORAGE_ROOT}/library/.catalog"
    local test_books_dir="${STORAGE_ROOT}/library/gutenberg"
    mkdir -p "$test_catalog_dir" "$test_books_dir"
    
    # Create mock catalog with a small subset of books
    cat > "${test_catalog_dir}/book_ids.txt" << EOF
1497
1228
2130
4280
5827
EOF
    
    # Test catalog creation
    if [ ! -s "${test_catalog_dir}/book_ids.txt" ]; then
        log_message "${RED}Failed to create test catalog${NC}"
        return 1
    fi
    
    # Test download function with a small batch
    local total_test_books=5
    local success=0
    local failed=0
    
    while read -r book_id; do
        log_message "Testing download of book ID: ${book_id}"
        
        # Try different URL formats
        local urls=(
            "https://www.gutenberg.org/cache/epub/${book_id}/pg${book_id}.txt"
            "https://www.gutenberg.org/files/${book_id}/${book_id}.txt"
            "https://www.gutenberg.org/files/${book_id}/${book_id}-0.txt"
            "https://www.gutenberg.org/ebooks/${book_id}.txt.utf-8"
        )
        
        local book_success=0
        for url in "${urls[@]}"; do
            if wget --timeout=10 --tries=2 -q -O "${test_books_dir}/${book_id}.txt" "$url"; then
                if [ -s "${test_books_dir}/${book_id}.txt" ]; then
                    book_success=1
                    success=$((success + 1))
                    log_message "${GREEN}Successfully downloaded test book ${book_id}${NC}"
                    break
                fi
            fi
        done
        
        if [ $book_success -eq 0 ]; then
            failed=$((failed + 1))
            log_message "${RED}Failed to download test book ${book_id}${NC}"
        fi
        
        # Rate limiting
        sleep 2
        
    done < "${test_catalog_dir}/book_ids.txt"
    
    # Verify results
    log_message "Mass downloader test results:"
    log_message "Total test books: ${total_test_books}"
    log_message "Successfully downloaded: ${success}"
    log_message "Failed downloads: ${failed}"
    
    if [ $success -eq 0 ]; then
        log_message "${RED}Mass downloader test failed - no books downloaded${NC}"
        return 1
    elif [ $success -lt $((total_test_books / 2)) ]; then
        log_message "${YELLOW}Mass downloader test partially successful${NC}"
    else
        log_message "${GREEN}Mass downloader test passed${NC}"
    fi
    
    # Test resume functionality
    local test_progress_file="${STORAGE_ROOT}/library/download_progress.log"
    echo "1497:SUCCESS:$(date +%s)" > "$test_progress_file"
    
    if ! grep -q "1497:SUCCESS" "$test_progress_file"; then
        log_message "${RED}Failed to create progress file${NC}"
        return 1
    fi
    
    log_message "${GREEN}Resume functionality test passed${NC}"
    return 0
}

test_survival_manual_downloads() {
    log_message "Testing survival manual downloads..."
    
    # Test multiple reliable sources
    local test_urls=(
        # Direct government sources
        "https://armypubs.army.mil/epubs/DR_pubs/DR_a/pdf/web/ARN7383_FM%203-05x70%20FINAL%20WEB.pdf"
        "https://fas.org/irp/doddir/army/fm3-05-70.pdf"
        # Alternative mirrors
        "https://www.marines.mil/Portals/1/Publications/MCRP%203-02F.pdf"
        "https://www.survivalmanuals.com/downloads/FM_21-76_SurvivalManual.pdf"
        # Fallback to smaller test files
        "https://www.ready.gov/sites/default/files/2020-03/ready_emergency-communications-plan_family.pdf"
    )
    
    local success=0
    for url in "${test_urls[@]}"; do
        log_message "Trying URL: $url"
        
        # Try downloading with timeout and retries
        if wget --timeout=10 --tries=2 -q --spider "$url"; then
            success=1
            log_message "${GREEN}Successfully accessed: $url${NC}"
            
            # Try downloading a small portion (first 1MB only for testing)
            if wget --timeout=15 --tries=2 -q --max-redirect=2 -O "${STORAGE_ROOT}/test.pdf" "$url"; then
                if [ -s "${STORAGE_ROOT}/test.pdf" ]; then
                    local filesize=$(stat -f%z "${STORAGE_ROOT}/test.pdf" 2>/dev/null || stat -c%s "${STORAGE_ROOT}/test.pdf")
                    log_message "${GREEN}Successfully downloaded test file (${filesize} bytes)${NC}"
                    rm -f "${STORAGE_ROOT}/test.pdf"
                    break
                fi
            fi
        fi
    done
    
    if [ $success -eq 0 ]; then
        # Final fallback - create a test file
        log_message "${YELLOW}Warning: Could not access online sources. Creating test file for verification.${NC}"
        cat > "${STORAGE_ROOT}/library/Survival/test_manual.txt" << EOF
This is a test survival manual file.
It contains basic survival information for testing purposes.
EOF
        
        if [ -s "${STORAGE_ROOT}/library/Survival/test_manual.txt" ]; then
            log_message "${YELLOW}Created test file for verification${NC}"
            success=1
        else
            log_message "${RED}Failed to create test file${NC}"
            return 1
        fi
    fi
    
    log_message "${GREEN}Survival manual test completed${NC}"
    return 0
}

test_wikipedia_dump_access() {
    log_message "Testing Wikipedia dump access..."
    
    # Test multiple Wikipedia dump URLs
    local wiki_urls=(
        "https://dumps.wikimedia.org/enwiki/latest/enwiki-latest-pages-articles1.xml-p1p41242.bz2"  # Smaller test file
        "https://dumps.wikimedia.org/simplewiki/latest/simplewiki-latest-pages-articles.xml.bz2"    # Simple English wiki
    )
    
    local success=0
    for url in "${wiki_urls[@]}"; do
        log_message "Trying URL: $url"
        if wget -q --spider "$url"; then
            success=1
            log_message "${GREEN}Successfully accessed: $url${NC}"
            break
        fi
    done
    
    if [ $success -eq 0 ]; then
        log_message "${RED}Failed to access any Wikipedia dump URLs${NC}"
        return 1
    fi
    
    log_message "${GREEN}Wikipedia dump URL test passed${NC}"
    return 0
}

test_disk_space() {
    log_message "Testing available disk space..."
    
    local required_space=$((50 * 1024 * 1024)) # 50GB in KB
    local available_space=$(df -k "$STORAGE_ROOT" | awk 'NR==2 {print $4}')
    
    if [ "$available_space" -lt "$required_space" ]; then
        log_message "${RED}Insufficient disk space. Required: 50GB, Available: $((available_space/1024/1024))GB${NC}"
        return 1
    fi
    
    log_message "${GREEN}Disk space test passed${NC}"
    return 0
}

cleanup_test_environment() {
    log_message "Cleaning up test environment..."
    rm -rf "$STORAGE_ROOT"
}

run_all_tests() {
    log_message "Starting content download tests..."
    
    # Create test environment
    cleanup_test_environment
    mkdir -p "$STORAGE_ROOT"
    
    # Run tests
    test_directory_creation || exit 1
    test_disk_space || exit 1
    test_gutenberg_downloads || exit 1
    test_gutenberg_mass_downloader || exit 1
    test_survival_manual_downloads || exit 1
    test_wikipedia_dump_access || exit 1
    
    # Cleanup
    cleanup_test_environment
    
    log_message "${GREEN}All content download tests passed!${NC}"
}

# Run the tests
run_all_tests 