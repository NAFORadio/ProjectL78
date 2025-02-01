#!/bin/bash

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
STORAGE_DIR="/mnt/data/Books"
LOG_FILE="$STORAGE_DIR/logs/gutenberg_download.log"
CATALOG_FILE="$STORAGE_DIR/catalog.csv"

# Gutenberg mirrors with direct book download URLs
MIRRORS=(
    "https://www.gutenberg.org/cache/epub"
    "https://gutenberg.pglaf.org/cache/epub"
    "http://mirrors.xmission.com/gutenberg/cache/epub"
    "http://gutenberg.readingroo.ms/cache/epub"
)

# Topics of interest with search terms
declare -A TOPICS=(
    ["mechanics"]="mechanics|machines|physics|mechanical engineering"
    ["medicine"]="medicine|medical|anatomy|first aid|surgery|healing"
    ["electronics"]="electronics|electrical|circuits|radio|telegraph"
    ["programming"]="programming|computer|python|linux|unix|algorithm"
    ["philosophy"]="philosophy|ethics|logic|reasoning|metaphysics"
    ["civics"]="civics|government|democracy|constitution|law|rights"
    ["art"]="art|drawing|painting|sculpture|design|architecture"
    ["survival"]="survival|wilderness|farming|agriculture|hunting|foraging"
    ["engineering"]="engineering|construction|building|materials|tools"
    ["leadership"]="leadership|management|command|authority|influence|motivation|organization"
    ["military"]="military|strategy|tactics|warfare|combat|defense|army|navy|war|battle|command"
)

# EPUB viewer options (in order of preference)
EPUB_VIEWERS=(
    "calibre"
    "foliate"
    "fbreader"
)

# Function to log messages
log_message() {
    echo -e "$1"
    if [ ! -f "$LOG_FILE" ]; then
        mkdir -p "$(dirname "$LOG_FILE")"
    fi
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to install EPUB viewer
install_epub_viewer() {
    local viewer_installed=false
    
    for viewer in "${EPUB_VIEWERS[@]}"; do
        echo -e "${YELLOW}Attempting to install $viewer...${NC}"
        if sudo apt-get install -y "$viewer"; then
            viewer_installed=true
            
            # Create desktop entry for all users
            sudo cat > "/usr/share/applications/$viewer.desktop" << EOF
[Desktop Entry]
Name=$viewer
Comment=EPUB Reader
Exec=$viewer %f
Icon=$viewer
Terminal=false
Type=Application
Categories=Office;Viewer;
MimeType=application/epub+zip;
EOF
            
            # Update desktop database
            sudo update-desktop-database
            
            echo -e "${GREEN}Successfully installed $viewer${NC}"
            break
        fi
    done
    
    if [ "$viewer_installed" = false ]; then
        echo -e "${RED}Failed to install any EPUB viewer${NC}"
        exit 1
    fi
}

# Function to sanitize filenames
sanitize_filename() {
    local filename="$1"
    echo "$filename" | tr -cd '[:alnum:] ._-' | tr ' ' '_' | tr -s '_' | cut -c1-150
}

# Function to get sudo privileges
get_sudo() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${YELLOW}This script requires administrative privileges.${NC}"
        sudo -v
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to get administrative privileges.${NC}"
            exit 1
        fi
    fi
}

# Function to download a book in multiple formats
download_book() {
    local book_id="$1"
    local title="$2"
    local author="$3"
    local topic="$4"
    local output_dir="$STORAGE_DIR/books/$topic"
    local download_success=false
    
    # Create topic directory if it doesn't exist
    mkdir -p "$output_dir"
    
    # Sanitize title and author for filename
    local safe_title=$(sanitize_filename "$title")
    local safe_author=$(sanitize_filename "$author")
    
    # Try to download both text and epub formats
    local formats=("txt" "epub")
    declare -A downloaded_files
    
    for format in "${formats[@]}"; do
        for mirror in "${MIRRORS[@]}"; do
            local url="${mirror}/${book_id}/pg${book_id}.${format}"
            log_message "${YELLOW}Attempting to download ${format} from: $url${NC}"
            
            if wget -q --spider "$url"; then
                local filename="${book_id}_${safe_author}_${safe_title}.${format}"
                if wget -q -O "$output_dir/$filename" "$url"; then
                    log_message "${GREEN}Successfully downloaded: $filename${NC}"
                    downloaded_files[$format]="$filename"
                    download_success=true
                    break
                fi
            fi
        done
    done
    
    if [ "$download_success" = true ]; then
        # Create metadata file
        local meta_file="$output_dir/${book_id}_${safe_author}_${safe_title}.meta"
        cat > "$meta_file" << EOF
Title: $title
Author: $author
Book ID: $book_id
Formats: ${!downloaded_files[*]}
Download Date: $(date '+%Y-%m-%d')
Source: Project Gutenberg
Topic: $topic

Downloaded Files:
EOF
        
        for format in "${!downloaded_files[@]}"; do
            echo "${format}: ${downloaded_files[$format]}" >> "$meta_file"
            # Add to catalog with format information
            echo "$book_id,$title,$author,$topic,${downloaded_files[$format]},$(date '+%Y-%m-%d')" >> "$CATALOG_FILE"
        done
        
        return 0
    fi
    
    log_message "${RED}Failed to download book ID: $book_id in any format${NC}"
    return 1
}

# Function to process catalog
process_catalog() {
    local catalog_url="https://www.gutenberg.org/cache/epub/feeds/pg_catalog.csv"
    local catalog_file="$STORAGE_DIR/catalog/pg_catalog.csv"
    
    log_message "${YELLOW}Downloading Gutenberg catalog...${NC}"
    mkdir -p "$STORAGE_DIR/catalog"
    
    if ! wget -q -O "$catalog_file" "$catalog_url"; then
        log_message "${RED}Failed to download catalog${NC}"
        exit 1
    fi
    
    # Create catalog with headers
    echo "ID,Title,Author,Topic,Filename,Date_Added" > "$CATALOG_FILE"
    
    # Process catalog with improved parsing
    tail -n +2 "$catalog_file" | while IFS=, read -r id title author subject language rights; do
        # Skip non-English books or those with copyright
        if [[ "$language" != "en" ]] || [[ "$rights" != "Public domain in the USA." ]]; then
            continue
        fi
        
        # Clean up author name
        author=$(echo "$author" | sed 's/^\([^,]*\),\s*\([^,]*\)$/\2 \1/')
        
        for topic in "${!TOPICS[@]}"; do
            if echo "$subject $title" | grep -iE "${TOPICS[$topic]}" > /dev/null; then
                log_message "${YELLOW}Processing: $title by $author${NC}"
                download_book "$id" "$title" "$author" "$topic"
                break
            fi
        done
    done
}

# Main function
main() {
    # Get sudo privileges at the start
    get_sudo
    
    log_message "${YELLOW}Starting Gutenberg download process...${NC}"
    
    # Install EPUB viewer
    log_message "${YELLOW}Installing EPUB viewer...${NC}"
    install_epub_viewer
    
    # Create necessary directories
    mkdir -p "$STORAGE_DIR"/{books,logs,catalog}
    
    # Process catalog and download books
    process_catalog
    
    log_message "${GREEN}Download process complete${NC}"
    log_message "Books have been saved to: $STORAGE_DIR"
    
    # Generate HTML index
    generate_html_index
    
    echo -e "${GREEN}EPUB viewer has been installed and configured.${NC}"
    echo -e "${YELLOW}You can now open EPUB files from the menu or by double-clicking them.${NC}"
}

# Function to generate HTML index
generate_html_index() {
    local index_file="$STORAGE_DIR/index.html"
    
    cat > "$index_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Gutenberg Library Index</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .book { margin-bottom: 20px; padding: 10px; border: 1px solid #ccc; }
        .title { font-weight: bold; }
        .author { color: #666; }
        .meta { font-size: 0.9em; color: #888; }
    </style>
</head>
<body>
    <h1>Gutenberg Library Index</h1>
    <div class="books">
EOF
    
    # Add each book to the index
    while IFS=, read -r id title author topic filename date; do
        [[ "$id" == "ID" ]] && continue  # Skip header
        cat >> "$index_file" << EOF
        <div class="book">
            <div class="title">$title</div>
            <div class="author">by $author</div>
            <div class="meta">
                Topic: $topic<br>
                File: $filename<br>
                Added: $date
            </div>
        </div>
EOF
    done < "$CATALOG_FILE"
    
    # Close HTML
    cat >> "$index_file" << EOF
    </div>
</body>
</html>
EOF
}

# Run main process
main 