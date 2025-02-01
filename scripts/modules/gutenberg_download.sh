#!/bin/bash

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
if [[ "$OSTYPE" == "darwin"* ]]; then
    STORAGE_DIR="$HOME/Desktop/Storage/Books"
else
    STORAGE_DIR="/home/storage/Books"
fi

LOG_FILE="$STORAGE_DIR/logs/gutenberg_download.log"
CATALOG_FILE="$STORAGE_DIR/catalog.csv"
FAILED_BOOKS_LOG="$STORAGE_DIR/logs/failed_books.csv"

# Retry configuration
MAX_RETRIES=3
RETRY_DELAY=5

# Gutenberg mirrors
MIRRORS=(
    "https://www.gutenberg.org/cache/epub"
    "https://gutenberg.pglaf.org/cache/epub"
    "http://mirrors.xmission.com/gutenberg/cache/epub"
    "http://gutenberg.readingroo.ms/cache/epub"
    "https://gutenberg.org/cache/epub"
    "http://aleph.gutenberg.org/cache/epub"
    "http://gutenberg.readingroo.ms/cache/epub"
    "http://gutenberg.localhost.net.ar/cache/epub"
    "http://gutenberg.polytechnic.edu.na/cache/epub"
    "http://gutenberg.cs.uiuc.edu/cache/epub"
    "http://eremita.di.uminho.pt/gutenberg/cache/epub"
    "http://mirror.csclub.uwaterloo.ca/gutenberg/cache/epub"
    "http://mirrors.xmission.com/gutenberg/cache/epub"
    "http://gutenberg.mirror.quintex.com/cache/epub"
)

# Topics as arrays instead of associative arrays
TOPICS=(
    "science:science|physics|chemistry|biology|astronomy|laboratory|experiment|scientific"
    "history:history|war|revolution|biography|civilization|empire|historical|conquest"
    "mathematics:mathematics|algebra|geometry|calculus|arithmetic|mathematical|computation"
    "survival:survival|wilderness|outdoor|camping|hunting|fishing|bushcraft|emergency"
    "gardening:gardening|horticulture|plants|flowers|vegetables|botanical|cultivation"
    "philosophy:philosophy|ethics|logic|metaphysics|philosophical|reasoning|wisdom"
    "farming:farming|agriculture|livestock|crops|husbandry|dairy|agricultural"
    "electronics:electricity|electronics|circuits|electrical|radio|telegraph|engineering"
    "mechanics:mechanics|machinery|engines|mechanical|engineering|motors|machines"
    "programming:computation|computer|algorithm|calculation|programming|mathematical"
)

# Known good books as arrays
KNOWN_BOOKS=(
    "science:103:The Principles of Chemistry:Mendeleev"
    "science:2713:Relativity\: The Special and General Theory:Einstein"
    "history:2591:The Art of War:Sun Tzu"
    "history:1404:The Decline and Fall of the Roman Empire:Gibbon"
    "mathematics:13700:The Elements of Euclid:Euclid"
    "mathematics:21690:A Treatise on Algebra:Hall"
    "survival:26989:Woodcraft:Nessmuk"
    "survival:28255:The Book of Camp-Lore and Woodcraft:Beard"
    "gardening:24494:Garden Design and Architects Gardens:Sedding"
    "gardening:23858:The Wild Garden:Robinson"
    "philosophy:1656:The Republic:Plato"
    "philosophy:1497:The Ethics:Spinoza"
    "farming:24500:Farming for Boys:Morris"
    "farming:25064:The First Book of Farming:Goodrich"
    "electronics:29784:The Radio Amateur's Hand Book:Collins"
    "electronics:29095:Electricity for Boys:Adams"
    "mechanics:30288:The Steam Engine Explained:Dionysius"
    "mechanics:12083:Gas and Oil Engines:Clerk"
    "programming:27635:Mathematical Analysis:Hardy"
    "programming:33283:The Calculus of Variations:Todhunter"
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

# Function to log messages
log_message() {
    echo -e "$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to log failed book
log_failed_book() {
    local id="$1"
    local title="$2"
    local author="$3"
    local reason="$4"
    
    # Create failed books log if it doesn't exist
    if [ ! -f "$FAILED_BOOKS_LOG" ]; then
        echo "ID,Title,Author,Reason,Date" > "$FAILED_BOOKS_LOG"
    fi
    
    echo "$id,\"$title\",\"$author\",\"$reason\",$(date '+%Y-%m-%d %H:%M:%S')" >> "$FAILED_BOOKS_LOG"
}

# Function to test mirror speed
test_mirror_speed() {
    local mirror="$1"
    local test_file="1/pg1.txt"
    local start_time end_time duration
    
    start_time=$(date +%s.%N)
    if curl -s "${mirror}/${test_file}" -o /dev/null; then
        end_time=$(date +%s.%N)
        duration=$(echo "$end_time - $start_time" | bc)
        echo "$duration $mirror"
    else
        echo "999999 $mirror"
    fi
}

# Function to sort mirrors by speed
sort_mirrors() {
    log_message "${YELLOW}Testing mirror speeds...${NC}"
    local temp_file=$(mktemp)
    
    for mirror in "${MIRRORS[@]}"; do
        log_message "Testing: $mirror"
        test_mirror_speed "$mirror" >> "$temp_file"
    done
    
    SORTED_MIRRORS=()
    while read -r speed mirror; do
        if [ "$speed" != "999999" ]; then
            SORTED_MIRRORS+=("$mirror")
            log_message "${GREEN}Mirror: $mirror - Speed: ${speed}s${NC}"
        else
            log_message "${RED}Mirror failed: $mirror${NC}"
        fi
    done < <(sort -n "$temp_file")
    
    rm -f "$temp_file"
    
    if [ ${#SORTED_MIRRORS[@]} -eq 0 ]; then
        log_message "${RED}No responsive mirrors found${NC}"
        exit 1
    fi
    
    log_message "${GREEN}Using fastest mirror: ${SORTED_MIRRORS[0]}${NC}"
}

# Function to retry downloads
retry_download() {
    local url="$1"
    local output="$2"
    local attempt=1
    
    while [ $attempt -le $MAX_RETRIES ]; do
        log_message "Download attempt $attempt of $MAX_RETRIES..."
        
        if curl -s -o "$output" "$url"; then
            log_message "${GREEN}Download successful on attempt $attempt${NC}"
            return 0
        else
            log_message "${YELLOW}Attempt $attempt failed${NC}"
            if [ $attempt -lt $MAX_RETRIES ]; then
                log_message "Waiting ${RETRY_DELAY} seconds before retry..."
                sleep $RETRY_DELAY
            fi
            ((attempt++))
        fi
    done
    
    return 1
}

# Function to download a book
download_book() {
    local book_id="$1"
    local title="$2"
    local author="$3"
    local subject="$4"
    local output_dir="$STORAGE_DIR/books"
    
    mkdir -p "$output_dir"
    
    local safe_title=$(echo "$title" | tr -cd '[:alnum:] ._-' | tr ' ' '_')
    local safe_author=$(echo "$author" | tr -cd '[:alnum:] ._-' | tr ' ' '_')
    
    # Try EPUB first
    log_message "${YELLOW}Checking for EPUB version of: $title${NC}"
    for mirror in "${SORTED_MIRRORS[@]}"; do
        local url="${mirror}/${book_id}/pg${book_id}.epub"
        local filename="${book_id}_${safe_author}_${safe_title}.epub"
        local full_path="$output_dir/$filename"
        
        if curl -s --head "$url" | head -n 1 | grep "HTTP/1.[01] [23].*" > /dev/null; then
            log_message "Downloading EPUB from $mirror"
            
            if retry_download "$url" "$full_path"; then
                log_message "${GREEN}Successfully downloaded EPUB: $filename${NC}"
                echo "$book_id,$title,$author,$subject,$filename,epub,$(date '+%Y-%m-%d'),$full_path" >> "$CATALOG_FILE"
                return 0
            fi
        fi
    done
    
    # Try TXT if EPUB fails
    log_message "${YELLOW}No EPUB found, trying TXT version...${NC}"
    for mirror in "${SORTED_MIRRORS[@]}"; do
        local url="${mirror}/${book_id}/pg${book_id}.txt"
        local filename="${book_id}_${safe_author}_${safe_title}.txt"
        local full_path="$output_dir/$filename"
        
        if curl -s --head "$url" | head -n 1 | grep "HTTP/1.[01] [23].*" > /dev/null; then
            log_message "Downloading TXT from $mirror"
            
            if retry_download "$url" "$full_path"; then
                log_message "${YELLOW}Successfully downloaded TXT: $filename${NC}"
                echo "$book_id,$title,$author,$subject,$filename,txt,$(date '+%Y-%m-%d'),$full_path" >> "$CATALOG_FILE"
                return 0
            fi
        fi
    done
    
    log_failed_book "$book_id" "$title" "$author" "Failed after $MAX_RETRIES retries"
    return 1
}

# Main function
main() {
    log_message "Starting Gutenberg download process..."
    mkdir -p "$STORAGE_DIR/books" "$STORAGE_DIR/logs"
    
    # Initialize catalog
    echo "ID,Title,Author,Subject,Filename,Format,Date_Added,Full_Path" > "$CATALOG_FILE"
    
    # Sort mirrors by speed
    sort_mirrors
    
    # Process catalog
    local catalog_url="https://www.gutenberg.org/cache/epub/feeds/pg_catalog.csv"
    local catalog_file="$STORAGE_DIR/catalog/pg_catalog.csv"
    
    mkdir -p "$STORAGE_DIR/catalog"
    
    log_message "Downloading Gutenberg catalog..."
    if ! curl -s -o "$catalog_file" "$catalog_url"; then
        log_message "${RED}Failed to download catalog${NC}"
        exit 1
    fi
    
    local total=0
    local success=0
    
    while IFS=, read -r id title author subject language; do
        [ "$id" = "Text#" ] && continue
        
        ((total++))
        title=$(echo "$title" | tr -d '"' | sed 's/^\s*//;s/\s*$//')
        author=$(echo "$author" | tr -d '"' | sed 's/^\s*//;s/\s*$//')
        subject=$(echo "$subject" | tr -d '"' | sed 's/^\s*//;s/\s*$//')
        
        log_message "Processing ($total): $title by $author"
        
        if download_book "$id" "$title" "$author" "$subject"; then
            ((success++))
        fi
    done < "$catalog_file"
    
    log_message "${GREEN}Download complete!${NC}"
    log_message "Total books processed: $total"
    log_message "Successfully downloaded: $success"
}

# Run main process
main 