#!/bin/bash
# Test suite for Primitive Technology Video Downloader

source "$(dirname "$0")/../../scripts/common/utils.sh"
source "$(dirname "$0")/../modules/primitive_tech_downloader.sh"

# Test configuration
TEST_DIR="/tmp/test_primitive_tech"
ORIGINAL_STORAGE_ROOT="$STORAGE_ROOT"
ORIGINAL_VIDEO_DIR="$VIDEO_DIR"
ORIGINAL_METADATA_DIR="$METADATA_DIR"

setup_test() {
    log_message "Setting up test environment..."
    STORAGE_ROOT="$TEST_DIR"
    VIDEO_DIR="${TEST_DIR}/videos/primitive_technology"
    METADATA_DIR="${VIDEO_DIR}/metadata"
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR"
}

cleanup_test() {
    log_message "Cleaning up test environment..."
    rm -rf "$TEST_DIR"
    STORAGE_ROOT="$ORIGINAL_STORAGE_ROOT"
    VIDEO_DIR="$ORIGINAL_VIDEO_DIR"
    METADATA_DIR="$ORIGINAL_METADATA_DIR"
}

test_setup_environment() {
    log_message "Testing setup_environment..."
    
    setup_environment
    
    # Test directory creation
    if [ ! -d "$VIDEO_DIR" ]; then
        log_message "${RED}Failed: VIDEO_DIR not created${NC}"
        return 1
    fi
    
    if [ ! -d "$METADATA_DIR" ]; then
        log_message "${RED}Failed: METADATA_DIR not created${NC}"
        return 1
    }
    
    # Test yt-dlp installation
    if ! command -v yt-dlp &>/dev/null; then
        log_message "${RED}Failed: yt-dlp not installed${NC}"
        return 1
    fi
    
    log_message "${GREEN}setup_environment test passed${NC}"
    return 0
}

test_channel_accessibility() {
    log_message "Testing channel accessibility..."
    
    # Test channel URL
    if ! curl -s -I "$CHANNEL_URL" | grep -q "200 OK"; then
        log_message "${RED}Failed: Channel URL not accessible${NC}"
        return 1
    fi
    
    # Test video listing accessibility
    if ! yt-dlp --flat-playlist --dump-json "$CHANNEL_URL/videos" | head -n 1 | grep -q "title"; then
        log_message "${RED}Failed: Cannot access video listing${NC}"
        return 1
    fi
    
    log_message "${GREEN}Channel accessibility test passed${NC}"
    return 0
}

test_single_video_download() {
    log_message "Testing single video download..."
    
    # Get first video URL
    local video_url=$(yt-dlp --flat-playlist --dump-json "$CHANNEL_URL/videos" | head -n 1 | jq -r '.url')
    
    # Test download with minimal size (download only first few bytes)
    if ! yt-dlp \
        --format "$FORMAT" \
        --write-info-json \
        --max-filesize 10M \
        --output "${VIDEO_DIR}/test_video.%(ext)s" \
        "$video_url"; then
        log_message "${RED}Failed: Cannot download test video${NC}"
        return 1
    fi
    
    # Check if metadata was created
    if [ ! -f "${VIDEO_DIR}/test_video.info.json" ]; then
        log_message "${RED}Failed: Metadata not created${NC}"
        return 1
    fi
    
    log_message "${GREEN}Single video download test passed${NC}"
    return 0
}

test_index_creation() {
    log_message "Testing index creation..."
    
    # Create test metadata
    mkdir -p "${VIDEO_DIR}/test_video"
    cat > "${VIDEO_DIR}/test_video/test.info.json" << EOF
{
    "title": "Test Video",
    "upload_date": "20240131",
    "description": "Test Description",
    "thumbnail": "test.jpg"
}
EOF
    touch "${VIDEO_DIR}/test_video/test.jpg"
    touch "${VIDEO_DIR}/test_video/test.mp4"
    
    # Test index creation
    create_index
    
    # Check if index was created
    if [ ! -f "${VIDEO_DIR}/index.html" ]; then
        log_message "${RED}Failed: Index not created${NC}"
        return 1
    fi
    
    # Check index content
    if ! grep -q "Test Video" "${VIDEO_DIR}/index.html"; then
        log_message "${RED}Failed: Index content incorrect${NC}"
        return 1
    fi
    
    log_message "${GREEN}Index creation test passed${NC}"
    return 0
}

run_tests() {
    local failed=0
    
    setup_test
    
    # Run individual tests
    test_setup_environment || ((failed++))
    test_channel_accessibility || ((failed++))
    test_single_video_download || ((failed++))
    test_index_creation || ((failed++))
    
    cleanup_test
    
    # Report results
    if [ "$failed" -eq 0 ]; then
        log_message "${GREEN}All tests passed successfully${NC}"
        return 0
    else
        log_message "${RED}$failed test(s) failed${NC}"
        return 1
    fi
}

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests
fi 