#!/bin/bash
# Primitive Technology Video Downloader
# Downloads all videos from Primitive Technology channel in space-efficient format

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Detect OS and architecture
get_os_type() {
    case "$(uname -s)" in
        Darwin*)    echo "macos";;
        Linux*)     echo "linux";;
        *)         echo "unknown";;
    esac
}

get_architecture() {
    case "$(uname -m)" in
        x86_64*)    echo "amd64";;
        arm64*)     echo "arm64";;
        aarch64*)   echo "arm64";;
        *)          echo "unknown";;
    esac
}

# Set paths based on OS
set_paths() {
    local os_type=$(get_os_type)
    case "$os_type" in
        macos)
            # Get current user's home directory
            local user_home=$HOME
            STORAGE_DIR="$user_home/Desktop/Share Files/Primitive_Technology"
            ;;
        linux)
            STORAGE_DIR="/storage/library/primitive_tech"
            ;;
        *)
            echo -e "${RED}Unsupported operating system${NC}"
            exit 1
            ;;
    esac
    
    # Create storage directory if it doesn't exist
    if [ ! -d "$STORAGE_DIR" ]; then
        echo -e "${YELLOW}Creating storage directory: $STORAGE_DIR${NC}"
        mkdir -p "$STORAGE_DIR"
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to create storage directory. Please check permissions.${NC}"
            exit 1
        fi
    fi
    
    # Set log file path and create log directory if needed
    LOG_DIR="$STORAGE_DIR/logs"
    mkdir -p "$LOG_DIR"
    LOG_FILE="$LOG_DIR/primitive_tech_download.log"
    
    # Ensure we can write to the directory
    if [ ! -w "$STORAGE_DIR" ]; then
        echo -e "${RED}Cannot write to $STORAGE_DIR${NC}"
        echo -e "${YELLOW}Attempting to fix permissions...${NC}"
        if [ "$os_type" = "macos" ]; then
            chown -R $(whoami) "$STORAGE_DIR"
        else
            sudo chown -R $(whoami) "$STORAGE_DIR"
        fi
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to set permissions. Please run:${NC}"
            echo "sudo chown -R $(whoami) \"$STORAGE_DIR\""
            exit 1
        fi
    fi
}

# Configuration
VIDEO_DIR="${STORAGE_DIR}/Primitive_Technology/Videos"
METADATA_DIR="${VIDEO_DIR}/metadata"
CHANNEL_URL="https://www.youtube.com/@primitivetechnology9550"
FORMAT="18"  # 360p MP4 - good balance of quality and size

# Setup logging
exec 1> >(tee -a "$LOG_FILE") 2>&1

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

setup_environment() {
    mkdir -p "$VIDEO_DIR" "$METADATA_DIR"
    
    # Check for yt-dlp
    if ! command -v yt-dlp &>/dev/null; then
        log_message "Installing yt-dlp..."
        python3 -m pip install --upgrade yt-dlp
    fi
}

# Check and install prerequisites based on OS
check_prerequisites() {
    log_message "Checking prerequisites..."
    local os_type=$(get_os_type)
    local arch=$(get_architecture)

    case "$os_type" in
        macos)
            install_mac_prerequisites "$arch"
            ;;
        linux)
            install_linux_prerequisites
            ;;
    esac
}

install_mac_prerequisites() {
    local arch="$1"
    
    # Check for Rosetta 2 on Apple Silicon
    if [[ "$arch" == "arm64" ]]; then
        if ! pkgutil --pkg-info=com.apple.pkg.RosettaUpdateAuto >/dev/null 2>&1; then
            echo -e "${YELLOW}Installing Rosetta 2 for Apple Silicon compatibility...${NC}"
            softwareupdate --install-rosetta --agree-to-license
        fi
    fi
    
    # Install Homebrew if needed
    if ! command -v brew &> /dev/null; then
        echo -e "${YELLOW}Installing Homebrew...${NC}"
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        if [[ "$arch" == "arm64" ]]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    fi
    
    # Install required packages
    brew install python yt-dlp wget ffmpeg
}

install_linux_prerequisites() {
    # Update package list
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y python3 python3-pip wget ffmpeg
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y python3 python3-pip wget ffmpeg
    elif command -v pacman &> /dev/null; then
        sudo pacman -Sy python python-pip wget ffmpeg
    else
        echo -e "${RED}Unsupported Linux distribution${NC}"
        exit 1
    fi
    
    # Install yt-dlp using pip
    sudo pip3 install --upgrade yt-dlp
}

# Download videos with OS-specific optimizations
download_videos() {
    # Updated channel URL with correct handle
    local channel_url="https://www.youtube.com/@primitivetechnology9550/videos"
    local output_template="$STORAGE_DIR/Videos/%(title)s.%(ext)s"
    
    echo -e "${YELLOW}Creating video directory...${NC}"
    mkdir -p "$STORAGE_DIR/Videos"
    
    echo -e "${YELLOW}Starting video download from: $channel_url${NC}"
    
    # First try to list available videos
    echo -e "${YELLOW}Checking channel availability...${NC}"
    if ! yt-dlp --flat-playlist --dump-json "$channel_url" > /dev/null 2>&1; then
        echo -e "${RED}Error: Cannot access channel. Please verify the URL.${NC}"
        return 1
    fi
    
    # Set concurrent fragments based on OS and architecture
    local threads=4
    if [[ "$(get_os_type)" == "macos" && "$(get_architecture)" == "arm64" ]]; then
        threads=8
    elif [[ "$(get_os_type)" == "linux" && "$(nproc)" -gt 4 ]]; then
        threads=$(nproc)
    fi
    
    echo -e "${YELLOW}Downloading videos with $threads threads...${NC}"
    
    # First attempt - 720p
    yt-dlp \
        --format "bestvideo[height<=720][ext=mp4]+bestaudio[ext=m4a]/best[height<=720][ext=mp4]/best[height<=720]" \
        --output "$output_template" \
        --write-description \
        --write-info-json \
        --write-thumbnail \
        --ignore-errors \
        --no-overwrites \
        --continue \
        --retries 10 \
        --fragment-retries 10 \
        --force-ipv4 \
        --no-playlist-reverse \
        --throttled-rate 100K \
        --concurrent-fragments $threads \
        --merge-output-format mp4 \
        --prefer-ffmpeg \
        --verbose \
        "$channel_url"
        
    local download_status=$?
    if [ $download_status -ne 0 ]; then
        echo -e "${YELLOW}First attempt failed. Trying with lower quality...${NC}"
        yt-dlp \
            --format "bestvideo[height<=480][ext=mp4]+bestaudio[ext=m4a]/best[height<=480][ext=mp4]/best[height<=480]" \
            --output "$output_template" \
            --ignore-errors \
            --no-overwrites \
            --continue \
            --retries 10 \
            --merge-output-format mp4 \
            --prefer-ffmpeg \
            --verbose \
            "$channel_url"
        
        download_status=$?
    fi
    
    # Check if any videos were downloaded
    if [ -d "$STORAGE_DIR/Videos" ] && [ "$(ls -A "$STORAGE_DIR/Videos")" ]; then
        log_message "${GREEN}Videos downloaded successfully${NC}"
        return 0
    else
        log_message "${RED}No videos were downloaded. Please check the channel URL.${NC}"
        return 1
    fi
}

# Function to create video index
create_video_index() {
    local videos_dir="$STORAGE_DIR/Videos"
    local index_file="$STORAGE_DIR/video_index.html"
    
    if [ ! -d "$videos_dir" ]; then
        log_message "${YELLOW}No videos directory found. Skipping index creation.${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}Creating video index...${NC}"
    
    # Create index HTML file
    cat > "$index_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Primitive Technology Videos</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .video-entry { margin-bottom: 20px; padding: 10px; border: 1px solid #ccc; }
        .video-title { font-weight: bold; }
        .video-desc { margin-top: 10px; }
    </style>
</head>
<body>
    <h1>Primitive Technology Videos</h1>
    <div class="video-list">
EOF
    
    # Add each video to the index
    find "$videos_dir" -name "*.mp4" | sort | while read video; do
        local title=$(basename "$video" .mp4)
        local desc_file="${video%.*}.description"
        
        echo "<div class='video-entry'>" >> "$index_file"
        echo "<div class='video-title'>$title</div>" >> "$index_file"
        if [ -f "$desc_file" ]; then
            echo "<div class='video-desc'>" >> "$index_file"
            cat "$desc_file" >> "$index_file"
            echo "</div>" >> "$index_file"
        fi
        echo "</div>" >> "$index_file"
    done
    
    # Close HTML file
    cat >> "$index_file" << EOF
    </div>
</body>
</html>
EOF
    
    log_message "${GREEN}Video index created at: $index_file${NC}"
}

# Modified main function
main() {
    local os_type=$(get_os_type)
    echo -e "${YELLOW}Detected OS: $os_type${NC}"
    echo -e "${YELLOW}Architecture: $(get_architecture)${NC}"
    
    set_paths
    check_prerequisites
    
    mkdir -p "$STORAGE_DIR"
    
    echo -e "\n${YELLOW}What would you like to download?${NC}"
    echo "1. Everything (videos, guides, and websites)"
    echo "2. Only videos"
    echo "3. Only guides and websites"
    read -p "Enter your choice (1-3): " choice
    
    case $choice in
        1)
            download_videos && create_video_index
            download_guides
            download_websites
            ;;
        2)
            download_videos && create_video_index
            ;;
        3)
            download_guides
            download_websites
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}Download complete!${NC}"
    echo -e "Content saved to: $STORAGE_DIR"
}

# Run main process
main

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi 