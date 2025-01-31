#!/bin/bash
# Primitive Technology Video Downloader
# Downloads all videos from Primitive Technology channel in space-efficient format

source "$(dirname "$0")/../common/utils.sh"

# Configuration
STORAGE_ROOT="${STORAGE_ROOT:-/storage}"
VIDEO_DIR="${STORAGE_ROOT}/videos/primitive_technology"
METADATA_DIR="${VIDEO_DIR}/metadata"
CHANNEL_URL="https://www.youtube.com/@primitivetechnology9550"
FORMAT="18"  # 360p MP4 - good balance of quality and size

setup_environment() {
    mkdir -p "$VIDEO_DIR" "$METADATA_DIR"
    
    # Check for yt-dlp
    if ! command -v yt-dlp &>/dev/null; then
        log_message "Installing yt-dlp..."
        python3 -m pip install --upgrade yt-dlp
    fi
}

download_videos() {
    log_message "Downloading Primitive Technology videos..."
    
    # Create archive file to track downloaded videos
    touch "${VIDEO_DIR}/downloaded.txt"
    
    # Download all videos with metadata
    yt-dlp \
        --format "$FORMAT" \
        --write-description \
        --write-info-json \
        --write-thumbnail \
        --write-sub \
        --sub-lang en \
        --download-archive "${VIDEO_DIR}/downloaded.txt" \
        --output "${VIDEO_DIR}/%(upload_date)s-%(title)s/%(title)s.%(ext)s" \
        --ignore-errors \
        --continue \
        --no-overwrites \
        --progress \
        "$CHANNEL_URL/videos"
    
    # Organize metadata
    find "$VIDEO_DIR" -name "*.info.json" -exec cp {} "$METADATA_DIR/" \;
}

create_index() {
    log_message "Creating video index..."
    
    # Create HTML index
    cat > "${VIDEO_DIR}/index.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Primitive Technology Video Archive</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 2em; }
        .video { border: 1px solid #ddd; padding: 1em; margin: 1em 0; }
        .thumbnail { max-width: 200px; }
    </style>
</head>
<body>
    <h1>Primitive Technology Video Archive</h1>
    <div class="videos">
EOF
    
    # Add each video to index
    find "$VIDEO_DIR" -name "*.info.json" | while read -r json_file; do
        title=$(jq -r '.title' "$json_file")
        date=$(jq -r '.upload_date' "$json_file")
        desc=$(jq -r '.description' "$json_file")
        thumb=$(dirname "$json_file")/$(basename "$json_file" .info.json).jpg
        video=$(dirname "$json_file")/$(basename "$json_file" .info.json).mp4
        
        cat >> "${VIDEO_DIR}/index.html" << EOF
        <div class="video">
            <img class="thumbnail" src="$(basename "$thumb")" alt="$title">
            <h2>$title</h2>
            <p>Upload date: $date</p>
            <p>$(echo "$desc" | head -n 3)</p>
            <a href="$(basename "$video")">Watch Video</a>
        </div>
EOF
    done
    
    # Close HTML
    cat >> "${VIDEO_DIR}/index.html" << EOF
    </div>
</body>
</html>
EOF
}

main() {
    setup_environment || exit 1
    
    if [ ! -f "${VIDEO_DIR}/.complete" ]; then
        download_videos || exit 1
        create_index || exit 1
        touch "${VIDEO_DIR}/.complete"
    else
        log_message "Videos already downloaded"
    fi
    
    log_message "${GREEN}Video archive complete${NC}"
    log_message "Videos available in: $VIDEO_DIR"
    log_message "Browse index at: ${VIDEO_DIR}/index.html"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi 