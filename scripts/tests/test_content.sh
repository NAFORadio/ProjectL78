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

test_survival_manual_downloads() {
    log_message "Testing survival manual downloads..."
    
    # Test multiple Archive.org URLs with different formats
    local test_manuals=(
        # Format: "identifier/filename"
        "FM21-76_1992/FM_21-76_1992.pdf"
        "fm21-76-1/fm21-76-1.pdf"
        "US-Army-Field-Manual-FM-21-76/US-Army-Field-Manual-FM-21-76.pdf"
        "military-survival-manual/military-survival-manual.pdf"
    )
    
    local success=0
    for manual in "${test_manuals[@]}"; do
        local identifier=$(echo "$manual" | cut -d'/' -f1)
        local filename=$(echo "$manual" | cut -d'/' -f2)
        
        # First check if item exists
        local metadata_url="https://archive.org/metadata/${identifier}"
        log_message "Checking item: ${identifier}"
        
        if curl -s --head "$metadata_url" | grep -q "200 OK"; then
            # Try different URL formats
            local urls=(
                "https://archive.org/download/${identifier}/${filename}"
                "https://archive.org/download/${identifier}/files/${filename}"
                "https://ia800504.us.archive.org/download/${identifier}/${filename}"
            )
            
            for url in "${urls[@]}"; do
                log_message "Trying URL: $url"
                if wget -q --spider "$url"; then
                    success=1
                    log_message "${GREEN}Successfully accessed: $url${NC}"
                    
                    # Try downloading a small portion to verify
                    if wget -q --max-redirect=2 --tries=3 -O "${STORAGE_ROOT}/test.pdf" "$url"; then
                        if [ -s "${STORAGE_ROOT}/test.pdf" ]; then
                            log_message "${GREEN}Successfully downloaded test file${NC}"
                            rm -f "${STORAGE_ROOT}/test.pdf"
                            break 2  # Exit both loops if successful
                        fi
                    fi
                fi
            done
        fi
    done
    
    if [ $success -eq 0 ]; then
        # Fallback to alternative source
        local fallback_url="https://www.survivalschool.us/downloads/FM21-76-US-Army-Survival-Manual.pdf"
        log_message "Trying fallback URL: $fallback_url"
        if wget -q --spider "$fallback_url"; then
            success=1
            log_message "${GREEN}Successfully accessed fallback URL${NC}"
        else
            log_message "${RED}Failed to access any survival manual sources${NC}"
            return 1
        fi
    fi
    
    log_message "${GREEN}Survival manual URL test passed${NC}"
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
    test_survival_manual_downloads || exit 1
    test_wikipedia_dump_access || exit 1
    
    # Cleanup
    cleanup_test_environment
    
    log_message "${GREEN}All content download tests passed!${NC}"
}

# Run the tests
run_all_tests 