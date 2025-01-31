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
    
    # Test a single small book download
    local test_book="1497" # The Republic
    local url="https://www.gutenberg.org/files/${test_book}/${test_book}.txt"
    local target="${STORAGE_ROOT}/library/Literature/${test_book}.txt"
    
    wget -q --spider "$url"
    if [ $? -ne 0 ]; then
        log_message "${RED}Failed to access Gutenberg URL: $url${NC}"
        return 1
    fi
    
    log_message "${GREEN}Gutenberg URL test passed${NC}"
    return 0
}

test_survival_manual_downloads() {
    log_message "Testing survival manual downloads..."
    
    # Test access to Archive.org
    local test_manual="milmanual-fm-21-76-us-army-survival-manual"
    local url="https://archive.org/download/${test_manual}/${test_manual}.pdf"
    
    wget -q --spider "$url"
    if [ $? -ne 0 ]; then
        log_message "${RED}Failed to access Archive.org URL: $url${NC}"
        return 1
    fi
    
    log_message "${GREEN}Archive.org URL test passed${NC}"
    return 0
}

test_wikipedia_dump_access() {
    log_message "Testing Wikipedia dump access..."
    
    # Test access to Wikipedia dumps
    local wiki_url="https://dumps.wikimedia.org/enwiki/latest/enwiki-latest-pages-articles.xml.bz2"
    
    wget -q --spider "$wiki_url"
    if [ $? -ne 0 ]; then
        log_message "${RED}Failed to access Wikipedia dump URL: $wiki_url${NC}"
        return 1
    fi
    
    log_message "${GREEN}Wikipedia dump URL test passed${NC}"
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
    test_gutenberg_downloads || exit 1
    test_survival_manual_downloads || exit 1
    test_wikipedia_dump_access || exit 1
    
    # Cleanup
    cleanup_test_environment
    
    log_message "${GREEN}All content download tests passed!${NC}"
}

# Run the tests
run_all_tests 