#!/bin/bash
# Primitive Technology Video Downloader
# Downloads all videos from Primitive Technology channel in space-efficient format

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

clear  # Clear the screen first

# Print NAFO Radio banner and disclaimer
echo -e "${GREEN}"
cat << "EOF"
===============================================================
 _   _    _    _____ ___    ____          _ _       
| \ | |  / \  |  ___|   \   |  _ \ __ _ __| (_) ___  
|  \| | / _ \ | |_  | ()|   | |_) / _` / _` | |/ _ \ 
| |\  |/ ___ \|  _| |   |   |  _ < (_| (_| | | (_) |
|_| \_/_/   \_\_|   |___|   |_| \_\__,_\__,_|_|\___/ 
    
    Knowledge Acquisition Department
    Offline Content Archive Division
===============================================================

NAFO RADIO KNOWLEDGE ACQUISITION NOTICE
---------------------------------------------------------------
This is a NAFO Radio Knowledge Acquisition Department tool.
Authorized personnel only.

Department: Knowledge Acquisition
Division: Offline Content Archive
Classification: Educational/Archival
Version: 2.0.1
---------------------------------------------------------------

LEGAL NOTICE AND DISCLAIMER
---------------------------------------------------------------
1. This tool is part of the NAFO Radio Knowledge Acquisition
   system, designed for educational and archival purposes.

2. Copyright Notice:
   - All content remains property of respective copyright holders
   - Primitive Technology channel © John Plant
   - Tool created by NAFO Radio Knowledge Acquisition Department

3. Usage Requirements:
   - Authorized NAFO Radio personnel only
   - Educational/Research purposes only
   - Must comply with all applicable laws and regulations
   - Must have rights/permission for any content downloaded

4. Liability:
   - NAFO Radio assumes no responsibility for misuse
   - Users must ensure compliance with local regulations
   - For authorized educational purposes only

5. Classification:
   - Internal NAFO Radio tool
   - Not for public distribution
   - Handle in accordance with department guidelines
===============================================================
EOF
echo -e "${NC}"

# Require explicit acceptance
echo -e "${YELLOW}"
read -p "NAFO Radio Personnel - Do you acknowledge and accept these terms? (yes/no): " accept
if [[ ! "$accept" =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${RED}Terms not accepted. Terminating session...${NC}"
    exit 1
fi
echo -e "${NC}"

# Configuration
STORAGE_DIR="/Users/jason/Desktop/Share Files/Primitive_Technology"

# Create log directory first
mkdir -p "$STORAGE_DIR/logs"
LOG_FILE="$STORAGE_DIR/logs/primitive_tech_download.log"

# Detect OS and architecture
get_os_type() {
    case "$(uname -s 2>/dev/null)" in
        Darwin*)    echo "macos" ;;
        Linux*)     echo "linux" ;;
        CYGWIN*|MINGW*|MSYS*|Windows_NT) echo "windows" ;;
        *)         echo "unknown" ;;
    esac
}

get_architecture() {
    case "$(uname -m)" in
        x86_64*)    echo "amd64" ;;
        arm64*)     echo "arm64" ;;
        aarch64*)   echo "arm64" ;;
        *)          echo "unknown" ;;
    esac
}

# Logging function
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check and install prerequisites
check_prerequisites() {
    log_message "Checking prerequisites..."
    local os_type=$(get_os_type)
    local arch=$(get_architecture)

    case "$os_type" in
        macos)
            cat << "EOF"
===============================================================
                    MAC USER DETECTED
===============================================================

Really? A Mac? 
¯\_(ツ)_/¯

Look, we get it. You like:
- Paying too much for hardware
- Having Apple tell you what you can and can't do
- Pretending your computer is "creative"
- That glowing fruit logo
- Being part of the "ecosystem"

But hey, at least you're not using Windows!
===============================================================
EOF
            read -p "Press Enter to continue with your overpriced Unix machine..."
            install_mac_prerequisites "$arch"
            ;;
            
        linux)
            cat << "EOF"
===============================================================
                    LINUX USER DETECTED
===============================================================

                    ⭐️ AMAZING! ⭐️

You are clearly a person of culture and intelligence!

- Low power consumption: ✓
- Freedom to modify: ✓
- Actually owns their computer: ✓
- Perfect for end times computing: ✓
- Gigachad status: ✓

Your computer is ready for the apocalypse!
===============================================================
EOF
            sleep 2  # Let them bask in their glory
            install_linux_prerequisites
            ;;
            
        windows)
            show_windows_warning
            read -p "Enter your choice (1-3): " choice
            case $choice in
                1)
                    echo -e "${YELLOW}Proceeding with Windows setup (not recommended)...${NC}"
                    install_windows_prerequisites
                    ;;
                2)
                    echo -e "${GREEN}Opening Linux alternatives information...${NC}"
                    echo "Visit: https://www.raspberrypi.org/"
                    echo "Visit: https://www.pine64.org/"
                    exit 0
                    ;;
                3)
                    echo -e "${GREEN}Good choice! Please consider switching to a Linux-based system.${NC}"
                    exit 0
                    ;;
                *)
                    echo -e "${RED}Invalid choice. Exiting...${NC}"
                    exit 1
                    ;;
            esac
            ;;
        *)
            echo -e "${RED}Unsupported operating system${NC}"
            exit 1
            ;;
    esac
}

install_mac_prerequisites() {
    local arch="$1"
    
    # Check for Homebrew
    if ! command -v brew &> /dev/null; then
        echo -e "${YELLOW}Installing Homebrew...${NC}"
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        if [[ "$arch" == "arm64" ]]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    fi
    
    # Check for Python specifically
    if ! command -v python3 &> /dev/null; then
        echo -e "${YELLOW}Installing Python...${NC}"
        brew install python3
    fi
    
    # Install other required packages quietly
    echo -e "${YELLOW}Installing required packages...${NC}"
    {
        brew install yt-dlp wget ffmpeg 2>&1 | grep -v "already installed" | grep -v "To reinstall"
    } &>/dev/null
    
    # Verify installations
    local missing_packages=()
    for cmd in python3 yt-dlp wget ffmpeg; do
        if ! command -v $cmd &>/dev/null; then
            missing_packages+=($cmd)
        fi
    done
    
    if [ ${#missing_packages[@]} -ne 0 ]; then
        echo -e "${RED}Failed to install: ${missing_packages[*]}${NC}"
        echo -e "${YELLOW}Attempting manual installation...${NC}"
        
        for pkg in "${missing_packages[@]}"; do
            echo -e "${YELLOW}Installing $pkg...${NC}"
            brew install $pkg
        done
        
        # Verify again
        for cmd in "${missing_packages[@]}"; do
            if ! command -v $cmd &>/dev/null; then
                echo -e "${RED}Failed to install $cmd${NC}"
                exit 1
            fi
        done
    fi
    
    echo -e "${GREEN}All required packages are installed${NC}"
}

install_linux_prerequisites() {
    # Update package list
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y python3 python3-pip wget ffmpeg
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y python3 python3-pip wget ffmpeg
    else
        echo -e "${RED}Unsupported Linux distribution${NC}"
        exit 1
    fi
    
    # Install yt-dlp using pip
    sudo pip3 install --upgrade yt-dlp
}

# Add Windows warning function
show_windows_warning() {
    cat << "EOF"
===============================================================
                    IMPORTANT NOTICE
===============================================================

Windows is NOT recommended for end times computing!

Reasons:
1. High power consumption
2. Complex dependency chains
3. Limited offline capabilities
4. Poor reliability in austere conditions
5. Difficult to repair/maintain without internet

RECOMMENDATION:
Consider switching to a low-power Linux device such as:
- Raspberry Pi
- Pine64
- Rock64
- Other ARM-based SBCs

These devices offer:
- Low power consumption (can run on solar)
- Simple, maintainable systems
- Better offline capabilities
- More reliable in difficult conditions
- Easier to repair/replace
- Better suited for knowledge preservation

Would you like to:
1. Continue anyway (not recommended)
2. Learn more about Linux alternatives
3. Exit and reconsider your setup

EOF
}

# Add Windows-specific prerequisites
install_windows_prerequisites() {
    echo -e "${YELLOW}Installing Windows prerequisites...${NC}"
    
    # Check for Chocolatey
    if ! command -v choco &> /dev/null; then
        echo -e "${YELLOW}Installing Chocolatey package manager...${NC}"
        powershell -Command "Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))"
    fi
    
    # Install required packages
    choco install -y python ffmpeg wget git
    
    # Install yt-dlp using pip
    pip install --upgrade yt-dlp
}

# Function to generate thumbnails
generate_thumbnails() {
    local videos_dir="$STORAGE_DIR/Videos"
    
    echo -e "${YELLOW}Generating thumbnails for videos...${NC}"
    
    # Check if ffmpeg is available
    if ! command -v ffmpeg &> /dev/null; then
        echo -e "${RED}ffmpeg is required for thumbnail generation${NC}"
        return 1
    fi
    
    # Process each video
    find "$videos_dir" -name "*.mp4" | while read video; do
        local thumb_file="${video%.*}.jpg"
        
        # Generate thumbnail if it doesn't exist or if video is newer
        if [ ! -f "$thumb_file" ] || [ "$video" -nt "$thumb_file" ]; then
            echo -e "${YELLOW}Generating thumbnail for: $(basename "$video")${NC}"
            ffmpeg -i "$video" -ss 00:00:02 -frames:v 1 -vf "scale=640:-1" "$thumb_file" -y 2>/dev/null
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Thumbnail created: $(basename "$thumb_file")${NC}"
            else
                echo -e "${RED}Failed to create thumbnail for: $(basename "$video")${NC}"
            fi
        fi
    done
}

# Function to verify video inclusion
verify_video_index() {
    local videos_dir="$STORAGE_DIR/Videos"
    local index_file="$STORAGE_DIR/video_index.html"
    local missing_videos=0
    
    echo -e "${YELLOW}Verifying video index completeness...${NC}"
    
    # Create temporary file to store video paths from index
    local temp_index_list=$(mktemp)
    local temp_dir_list=$(mktemp)
    
    # Extract video paths from index
    if [ -f "$index_file" ]; then
        grep -o 'href="Videos/[^"]*\.mp4"' "$index_file" | cut -d'"' -f2 | sort > "$temp_index_list"
    fi
    
    # Get list of actual videos in directory
    find "$videos_dir" -name "*.mp4" | sed "s|$STORAGE_DIR/||" | sort > "$temp_dir_list"
    
    # Compare lists
    echo -e "${YELLOW}Checking for missing videos...${NC}"
    local missing_count=0
    while IFS= read -r video; do
        if ! grep -q "^$video$" "$temp_index_list"; then
            echo -e "${RED}Missing from index: $video${NC}"
            missing_count=$((missing_count + 1))
        fi
    done < "$temp_dir_list"
    
    # Cleanup temp files
    rm -f "$temp_index_list" "$temp_dir_list"
    
    # Recreate index if missing videos found
    if [ $missing_count -gt 0 ]; then
        echo -e "${YELLOW}Found $missing_count missing videos. Recreating index...${NC}"
        create_video_index
        echo -e "${GREEN}Index has been updated with all videos${NC}"
    else
        echo -e "${GREEN}All videos are properly indexed${NC}"
    fi
}

# Function to create a stylish video index
create_video_index() {
    local videos_dir="$STORAGE_DIR/Videos"
    local index_file="$STORAGE_DIR/video_index.html"
    local video_count=0
    local current_date=$(date '+%Y-%m-%d %H:%M')
    
    if [ ! -d "$videos_dir" ]; then
        log_message "${YELLOW}No videos directory found. Skipping index creation.${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}Creating video index...${NC}"
    
    # Generate thumbnails first
    generate_thumbnails
    
    # Count total videos
    total_videos=$(find "$videos_dir" -name "*.mp4" | wc -l)
    echo -e "${YELLOW}Found $total_videos videos to index${NC}"
    
    # Create index HTML file with dynamic values
    cat > "$index_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Primitive Technology Archive</title>
    <style>
        :root {
            --matrix-green: #00ff41;
            --matrix-dark: #0a0a0a;
            --matrix-darker: #050505;
            --text-color: #cccccc;
        }
        body {
            font-family: 'Courier New', monospace;
            background-color: var(--matrix-darker);
            color: var(--text-color);
            margin: 0;
            padding: 20px;
            line-height: 1.6;
        }
        .header {
            text-align: center;
            padding: 20px;
            border-bottom: 1px solid var(--matrix-green);
            margin-bottom: 30px;
        }
        h1 {
            color: var(--matrix-green);
            text-shadow: 0 0 10px var(--matrix-green);
            margin-bottom: 10px;
        }
        .stats {
            color: var(--matrix-green);
            font-size: 0.9em;
            margin-bottom: 20px;
        }
        .video-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
            gap: 20px;
            padding: 20px;
        }
        .video-card {
            background-color: var(--matrix-dark);
            border: 1px solid var(--matrix-green);
            border-radius: 5px;
            overflow: hidden;
            transition: transform 0.2s, box-shadow 0.2s;
        }
        .video-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 0 15px var(--matrix-green);
        }
        .thumbnail {
            width: 100%;
            height: 169px;
            object-fit: cover;
            border-bottom: 1px solid var(--matrix-green);
        }
        .video-info {
            padding: 15px;
        }
        .video-title {
            color: var(--matrix-green);
            font-weight: bold;
            margin-bottom: 10px;
            font-size: 0.9em;
        }
        .video-desc {
            font-size: 0.8em;
            max-height: 100px;
            overflow-y: auto;
        }
        .video-link {
            display: block;
            text-decoration: none;
            color: inherit;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>Primitive Technology Archive</h1>
        <div class="stats">
            Total Videos: $total_videos | Last Updated: $current_date
        </div>
    </div>
    <div class="video-grid">
EOF

    # Add each video to the index
    find "$videos_dir" -name "*.mp4" | sort | while read video; do
        video_count=$((video_count + 1))
        echo -e "\rProcessing video $video_count of $total_videos: $(basename "$video")"
        
        local title=$(basename "$video" .mp4)
        local desc_file="${video%.*}.description"
        local thumb_file="${video%.*}.jpg"
        local relative_video_path="Videos/$(basename "$video")"
        local relative_thumb_path="Videos/$(basename "$thumb_file")"
        
        cat >> "$index_file" << EOF
        <div class="video-card">
            <a href="$relative_video_path" class="video-link">
                <img class="thumbnail" src="$relative_thumb_path" alt="$title">
                <div class="video-info">
                    <div class="video-title">$title</div>
EOF
        
        if [ -f "$desc_file" ]; then
            echo "<div class='video-desc'>" >> "$index_file"
            head -n 3 "$desc_file" >> "$index_file"
            echo "...</div>" >> "$index_file"
        fi
        
        echo "</div></a></div>" >> "$index_file"
    done
    
    # Close HTML file
    cat >> "$index_file" << EOF
    </div>
</body>
</html>
EOF
    
    log_message "${GREEN}Video index created with $total_videos videos${NC}"
}

# Download videos function
download_videos() {
    local channel_url="https://www.youtube.com/@primitivetechnology9550/videos"
    local output_template="$STORAGE_DIR/Videos/%(title)s.%(ext)s"
    
    mkdir -p "$STORAGE_DIR/Videos"
    
    echo -e "${YELLOW}Starting video download from: $channel_url${NC}"
    
    yt-dlp \
        --format "bestvideo[height<=720][ext=mp4]+bestaudio[ext=m4a]/best[height<=720][ext=mp4]/best[height<=720]" \
        --output "$output_template" \
        --write-description \
        --write-thumbnail \
        --ignore-errors \
        --continue \
        --retries 10 \
        --force-ipv4 \
        "$channel_url"
}

# Modified main function with quit option
main() {
    echo -e "${YELLOW}Primitive Technology Downloader${NC}"
    
    check_prerequisites
    
    while true; do
        echo -e "\n${YELLOW}What would you like to do?${NC}"
        echo "1. Download videos and create index"
        echo "2. Create/update index only"
        echo "3. Generate/update thumbnails only"
        echo "4. Verify and fix video index"
        echo "q. Quit"
        read -p "Enter your choice (1-4 or q): " choice
        
        case $choice in
            1)
                download_videos
                generate_thumbnails
                create_video_index
                verify_video_index
                ;;
            2)
                create_video_index
                verify_video_index
                ;;
            3)
                generate_thumbnails
                ;;
            4)
                verify_video_index
                ;;
            [qQ])
                echo -e "${GREEN}Exiting...${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice${NC}"
                ;;
        esac
        
        echo -e "${GREEN}Process complete!${NC}"
        echo -e "Content saved to: $STORAGE_DIR"
    done
}

# Run main process
main

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi 