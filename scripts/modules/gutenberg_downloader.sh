#!/bin/bash
# Gutenberg Library Downloader using Kiwix and OpenZIM
# Based on: https://github.com/openzim/gutenberg

source "$(dirname "$0")/../common/utils.sh"

# Configuration
STORAGE_ROOT="${STORAGE_ROOT:-/storage}"
KIWIX_DIR="${STORAGE_ROOT}/kiwix"
LIBRARY_DIR="${KIWIX_DIR}/library"
KIWIX_VERSION="3.6.0"

# Mirror configuration
declare -a MIRRORS=(
    "https://download.kiwix.org/zim/gutenberg/"
    "https://mirror.download.kiwix.org/zim/gutenberg/"
    "https://download.openzim.org/gutenberg/"
)

# Dependencies based on OpenZIM requirements
REQUIRED_PACKAGES=(
    "wget"
    "curl"
    "python3"
    "python3-pip"
    "libxml2-dev"
    "libxslt-dev"
    "advancecomp"
    "jpegoptim"
    "pngquant"
    "p7zip-full"
    "gifsicle"
    "zip"
    "zim-tools"
)

setup_environment() {
    mkdir -p "$KIWIX_DIR" "$LIBRARY_DIR"
}

check_dependencies() {
    local missing_packages=()
    
    log_message "Checking dependencies..."
    
    for package in "${REQUIRED_PACKAGES[@]}"; do
        if ! dpkg -l | grep -q "^ii.*$package"; then
            missing_packages+=("$package")
        fi
    done
    
    if [ ${#missing_packages[@]} -ne 0 ]; then
        log_message "${YELLOW}Missing required packages: ${missing_packages[*]}${NC}"
        log_message "Installing missing packages..."
        
        if command -v apt-get &>/dev/null; then
            sudo apt-get update && sudo apt-get install -y "${missing_packages[@]}"
            return $?
        else
            log_message "${RED}Package manager not found. Please install manually: ${missing_packages[*]}${NC}"
            return 1
        fi
    fi
    return 0
}

install_kiwix() {
    log_message "Installing Kiwix..."
    
    local kiwix_url="https://download.kiwix.org/release/kiwix-tools/kiwix-tools_linux-x86_64-${KIWIX_VERSION}.tar.gz"
    local kiwix_archive="${KIWIX_DIR}/kiwix-tools.tar.gz"
    
    if ! wget -q "$kiwix_url" -O "$kiwix_archive"; then
        log_message "${RED}Failed to download Kiwix${NC}"
        return 1
    fi
    
    if ! tar xzf "$kiwix_archive" -C "$KIWIX_DIR"; then
        log_message "${RED}Failed to extract Kiwix${NC}"
        rm -f "$kiwix_archive"
        return 1
    fi
    
    ln -sf "${KIWIX_DIR}/kiwix-tools_linux-x86_64-${KIWIX_VERSION}/kiwix-serve" "/usr/local/bin/kiwix-serve"
    ln -sf "${KIWIX_DIR}/kiwix-tools_linux-x86_64-${KIWIX_VERSION}/kiwix-manage" "/usr/local/bin/kiwix-manage"
    
    rm -f "$kiwix_archive"
    log_message "${GREEN}Kiwix installed successfully${NC}"
    return 0
}

find_best_mirror() {
    log_message "Finding fastest mirror..."
    local best_mirror=""
    local best_time=999999
    
    for mirror in "${MIRRORS[@]}"; do
        log_message "Testing mirror: $mirror"
        local start_time=$(date +%s.%N)
        if curl -s --head --fail "$mirror" >/dev/null; then
            local end_time=$(date +%s.%N)
            local time_taken=$(echo "$end_time - $start_time" | bc)
            
            if (( $(echo "$time_taken < $best_time" | bc -l) )); then
                best_time=$time_taken
                best_mirror=$mirror
                log_message "New best mirror: $mirror (${time_taken}s)"
            fi
        else
            log_message "${YELLOW}Mirror not responding: $mirror${NC}"
        fi
    done
    
    if [ -z "$best_mirror" ]; then
        log_message "${RED}No working mirrors found${NC}"
        return 1
    fi
    
    echo "$best_mirror"
    return 0
}

get_latest_zim_file() {
    local mirror="$1"
    local file_list
    file_list=$(curl -s "$mirror")
    
    echo "$file_list" | grep -o 'gutenberg_all_[0-9]\{4\}-[0-9]\{2\}.zim' | sort -r | head -1
}

download_gutenberg_zim() {
    log_message "Setting up Gutenberg ZIM download..."
    
    local mirror
    if ! mirror=$(find_best_mirror); then
        log_message "${RED}Failed to find working mirror${NC}"
        return 1
    fi
    
    log_message "Fetching available ZIM files..."
    local file_list
    if ! file_list=$(curl -s "$mirror"); then
        log_message "${RED}Failed to fetch file list${NC}"
        return 1
    fi
    
    local zim_file
    zim_file=$(echo "$file_list" | grep -o 'gutenberg_[a-z]*_[0-9]\{4\}-[0-9]\{2\}.zim' | sort -r | head -1)
    
    if [ -z "$zim_file" ]; then
        log_message "${RED}No ZIM files found${NC}"
        return 1
    fi
    
    log_message "Found latest version: $zim_file"
    
    local zim_path="${LIBRARY_DIR}/${zim_file}"
    local download_url="${mirror}${zim_file}"
    
    log_message "Download URL: $download_url"
    
    if [ -f "$zim_path" ]; then
        log_message "ZIM file exists. Verifying..."
        if verify_zim_file "$zim_path"; then
            log_message "${GREEN}Existing ZIM file is valid${NC}"
            return 0
        fi
        log_message "${YELLOW}Existing file corrupt, redownloading...${NC}"
        rm -f "$zim_path"
    fi
    
    log_message "Downloading Gutenberg ZIM file..."
    if ! wget --progress=bar:force:noscroll \
              --tries=3 \
              --timeout=60 \
              --continue \
              --no-verbose \
              "$download_url" \
              -O "${zim_path}.tmp"; then
        log_message "${RED}Download failed${NC}"
        rm -f "${zim_path}.tmp"
        return 1
    fi
    
    if verify_zim_file "${zim_path}.tmp"; then
        mv "${zim_path}.tmp" "$zim_path"
        log_message "${GREEN}Download successful${NC}"
        return 0
    else
        rm -f "${zim_path}.tmp"
        log_message "${RED}Downloaded file verification failed${NC}"
        return 1
    fi
}

verify_zim_file() {
    local file="$1"
    local min_size=$((1024*1024*1024))
    local file_size
    
    if ! file_size=$(stat -c%s "$file"); then
        log_message "${RED}Cannot get file size: $file${NC}"
        return 1
    fi
    
    if [ "$file_size" -lt "$min_size" ]; then
        log_message "${RED}File too small: $file${NC}"
        return 1
    fi
    
    if ! head -c 4 "$file" | grep -q "^ZIM."; then
        log_message "${RED}Invalid ZIM header: $file${NC}"
        return 1
    fi
    
    if ! dd if="$file" bs=1M skip=$((RANDOM % 1024)) count=1 of=/dev/null 2>/dev/null; then
        log_message "${RED}File read test failed: $file${NC}"
        return 1
    fi
    
    return 0
}

setup_kiwix_service() {
    log_message "Setting up Kiwix service..."
    
    cat > /etc/systemd/system/kiwix-gutenberg.service << EOF
[Unit]
Description=Kiwix Gutenberg Server
After=network.target
Documentation=https://github.com/openzim/gutenberg

[Service]
Type=simple
ExecStart=/usr/local/bin/kiwix-serve --port 8080 ${LIBRARY_DIR}/*.zim
Restart=always
RestartSec=10
User=root
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable kiwix-gutenberg
    systemctl start kiwix-gutenberg
    
    if systemctl is-active --quiet kiwix-gutenberg; then
        log_message "${GREEN}Kiwix service started successfully${NC}"
        log_message "Access the library at: http://localhost:8080"
        return 0
    else
        log_message "${RED}Failed to start Kiwix service${NC}"
        return 1
    fi
}

main() {
    if ! setup_environment; then
        log_message "${RED}Failed to create directories${NC}"
        return 1
    fi
    
    if ! check_dependencies; then
        log_message "${RED}Dependency check failed${NC}"
        return 1
    fi
    
    if ! install_kiwix; then
        log_message "${RED}Kiwix installation failed${NC}"
        return 1
    fi
    
    if ! download_gutenberg_zim; then
        log_message "${RED}ZIM file download failed${NC}"
        return 1
    fi
    
    if ! setup_kiwix_service; then
        log_message "${RED}Service setup failed${NC}"
        return 1
    fi
    
    log_message "${GREEN}Project Gutenberg library setup complete!${NC}"
    return 0
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi 