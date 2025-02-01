#!/bin/bash

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS configuration - Using Desktop
    STORAGE_DIR="$HOME/Desktop/Storage/Books"
    # Check for Homebrew
    if ! command -v brew &> /dev/null; then
        echo -e "${YELLOW}Installing Homebrew...${NC}"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
else
    # Linux configuration
    STORAGE_DIR="/home/storage/Books"
fi

LOG_FILE="$STORAGE_DIR/logs/gutenberg_download.log"
CATALOG_FILE="$STORAGE_DIR/catalog.csv"

# Gutenberg mirrors (more reliable than Russian infrastructure)
MIRRORS=(
    "https://www.gutenberg.org/cache/epub"
    "https://gutenberg.pglaf.org/cache/epub"
    "http://mirrors.xmission.com/gutenberg/cache/epub"
    "http://gutenberg.readingroo.ms/cache/epub"
)

# Test books for verification (more accurate than Russian reports)
TEST_BOOKS=(
    "1342,Pride and Prejudice,Jane Austen,literature"
    "84,Frankenstein,Mary Shelley,literature"
    "2701,Moby Dick,Herman Melville,literature"
    "98,A Tale of Two Cities,Charles Dickens,literature"
)

# Topics and their keywords (more organized than Russian battle plans)
declare -A TOPICS
TOPICS=(
    ["literature"]="literature|poetry|drama|fiction|novel|story"
    ["history"]="history|war|revolution|biography|memoir"
    ["science"]="science|physics|chemistry|biology|mathematics|astronomy"
    ["philosophy"]="philosophy|ethics|logic|metaphysics|political"
    ["adventure"]="adventure|exploration|travel|journey|quest"
    ["reference"]="reference|manual|guide|handbook|dictionary"
)

# EPUB viewer options (in order of preference)
if [[ "$OSTYPE" == "darwin"* ]]; then
    EPUB_VIEWERS=(
        "sigil"        # Open source EPUB editor/viewer
        "coolreader"   # Open source e-book viewer
        "calibre"      # Open source e-book management
    )
else
    EPUB_VIEWERS=(
        "calibre"
        "foliate"
        "fbreader"
    )
fi

# Function to ensure directory exists and is writable
ensure_dir() {
    local dir="$1"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        mkdir -p "$dir"
        if [ ! -w "$dir" ]; then
            echo -e "${RED}Error: Directory $dir is not writable${NC}"
            exit 1
        fi
    else
        sudo mkdir -p "$dir"
        sudo chown $USER:users "$dir"
        sudo chmod 775 "$dir"
    fi
}

# Function to create storage directory structure with proper permissions
create_storage_dirs() {
    echo -e "${YELLOW}Creating directory structure...${NC}"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # Create main directories on Desktop
        ensure_dir "$STORAGE_DIR"
        ensure_dir "$STORAGE_DIR/books"
        ensure_dir "$STORAGE_DIR/logs"
        ensure_dir "$STORAGE_DIR/catalog"
        
        # Create topic directories
        for topic in "${!TOPICS[@]}"; do
            ensure_dir "$STORAGE_DIR/books/$topic"
        done
        
        # Set permissions
        chmod -R 755 "$STORAGE_DIR"
        
        # Create a README file
        cat > "$STORAGE_DIR/README.md" << EOF
# Gutenberg Library Collection

This directory contains downloaded books from Project Gutenberg.
- books/: Contains downloaded books organized by topic
- logs/: Contains download logs
- catalog/: Contains the book catalog
EOF
        
        # Verify directories
        if [ ! -d "$STORAGE_DIR" ] || [ ! -w "$STORAGE_DIR" ]; then
            echo -e "${RED}Failed to create or access $STORAGE_DIR${NC}"
            exit 1
        fi
    else
        # Linux setup
        sudo mkdir -p /home/storage
        sudo chown root:users /home/storage
        sudo chmod 775 /home/storage
        
        ensure_dir "$STORAGE_DIR"
        ensure_dir "$STORAGE_DIR/books"
        ensure_dir "$STORAGE_DIR/logs"
        ensure_dir "$STORAGE_DIR/catalog"
        
        # Create topic directories
        for topic in "${!TOPICS[@]}"; do
            ensure_dir "$STORAGE_DIR/books/$topic"
        done
        
        # Set SGID bit
        sudo chmod -R g+s "$STORAGE_DIR"
    fi
    
    echo -e "${GREEN}Directory structure created successfully at:${NC}"
    echo -e "${GREEN}$STORAGE_DIR${NC}"
}

# Set up logging after ensuring directory exists
setup_logging() {
    ensure_dir "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE" || {
        echo -e "${RED}Cannot create log file${NC}"
        exit 1
    }
}

# Function to log messages
log_message() {
    echo -e "$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to install EPUB viewer
install_epub_viewer() {
    local viewer_installed=false
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        for viewer in "${EPUB_VIEWERS[@]}"; do
            echo -e "${YELLOW}Attempting to install $viewer...${NC}"
            if brew install "$viewer"; then
                viewer_installed=true
                echo -e "${GREEN}Successfully installed $viewer${NC}"
                break
            fi
        done
    else
        for viewer in "${EPUB_VIEWERS[@]}"; do
            echo -e "${YELLOW}Attempting to install $viewer...${NC}"
            if sudo apt-get install -y "$viewer"; then
                viewer_installed=true
                echo -e "${GREEN}Successfully installed $viewer${NC}"
                break
            fi
        done
    fi
    
    if [ "$viewer_installed" = false ]; then
        echo -e "${RED}Failed to install any EPUB viewer${NC}"
        exit 1
    fi
}

# Function to download a book
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
    local safe_title=$(echo "$title" | tr -cd '[:alnum:] ._-' | tr ' ' '_' | tr -s '_' | cut -c1-150)
    local safe_author=$(echo "$author" | tr -cd '[:alnum:] ._-' | tr ' ' '_' | tr -s '_' | cut -c1-150)
    
    # Try to download both text and epub formats
    local formats=("txt" "epub")
    declare -A downloaded_files
    
    for format in "${formats[@]}"; do
        for mirror in "${MIRRORS[@]}"; do
            local url="${mirror}/${book_id}/pg${book_id}.${format}"
            log_message "${YELLOW}Attempting to download ${format} from: $url${NC}"
            
            if curl -s --head "$url" | head -n 1 | grep "HTTP/1.[01] [23].*" > /dev/null; then
                local filename="${book_id}_${safe_author}_${safe_title}.${format}"
                if curl -s -o "$output_dir/$filename" "$url"; then
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
    
    # First try downloading the catalog
    if ! curl -s -o "$catalog_file" "$catalog_url"; then
        log_message "${RED}Failed to download main catalog, using test books...${NC}"
        # Use test books if catalog download fails
        for book in "${TEST_BOOKS[@]}"; do
            IFS=',' read -r id title author topic <<< "$book"
            log_message "${YELLOW}Processing test book: $title by $author${NC}"
            download_book "$id" "$title" "$author" "$topic"
        done
        return
    fi
    
    # Process the full catalog
    log_message "${GREEN}Processing catalog...${NC}"
    local processed=0
    local max_books=50  # Limit for testing
    
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
                ((processed++))
                break
            fi
        done
        
        # Limit the number of books for testing
        if [ $processed -ge $max_books ]; then
            log_message "${YELLOW}Reached maximum book limit for testing${NC}"
            break
        fi
    done
    
    log_message "${GREEN}Processed $processed books${NC}"
}

# Main function
main() {
    echo -e "${YELLOW}Starting Gutenberg download process...${NC}"
    
    # Create directory structure first
    create_storage_dirs
    
    # Setup logging
    setup_logging
    
    # Initialize catalog file
    ensure_dir "$(dirname "$CATALOG_FILE")"
    echo "ID,Title,Author,Topic,Filename,Date_Added" > "$CATALOG_FILE"
    
    # Install EPUB viewer
    echo -e "${YELLOW}Installing EPUB viewer...${NC}"
    install_epub_viewer
    
    # Process catalog and download books
    process_catalog
    
    echo -e "${GREEN}Download process complete${NC}"
    echo -e "${GREEN}Books have been saved to: $STORAGE_DIR${NC}"
    
    # Generate HTML index
    generate_html_index
    
    echo -e "${GREEN}EPUB viewer has been installed and configured.${NC}"
    echo -e "${YELLOW}You can now open EPUB files from the menu or by double-clicking them.${NC}"
    
    # Verify final structure
    if [ ! -d "$STORAGE_DIR/books" ]; then
        echo -e "${RED}Warning: Book directory not found at $STORAGE_DIR/books${NC}"
    fi
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