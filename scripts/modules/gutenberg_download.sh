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

# Define catalog sources
CATALOG_SOURCES=(
    "https://www.gutenberg.org/cache/epub/feeds/pg_catalog.csv"
    "https://gutenberg.pglaf.org/cache/epub/feeds/pg_catalog.csv"
    "http://mirrors.xmission.com/gutenberg/feeds/pg_catalog.csv"
    "http://gutenberg.readingroo.ms/feeds/pg_catalog.csv"
    "https://raw.githubusercontent.com/GITenberg/GITenberg.github.io/master/pg_catalog.csv"
    "https://gutenberg.polytechnic.edu.na/feeds/pg_catalog.csv"
)

# Define mirrors
MIRRORS=(
    "https://www.gutenberg.org/cache/epub"
    "https://gutenberg.pglaf.org/cache/epub"
    "http://mirrors.xmission.com/gutenberg/cache/epub"
    "http://gutenberg.readingroo.ms/cache/epub"
    "https://gutenberg.org/cache/epub"
    "http://aleph.gutenberg.org/cache/epub"
    "http://gutenberg.localhost.net.ar/cache/epub"
    "http://gutenberg.polytechnic.edu.na/cache/epub"
    "http://gutenberg.cs.uiuc.edu/cache/epub"
    "http://eremita.di.uminho.pt/gutenberg/cache/epub"
    "http://mirror.csclub.uwaterloo.ca/gutenberg/cache/epub"
)

# Topic patterns
TOPIC_PATTERNS=(
    "mathematics:math|algebra|geometry|calculus"
    "science:science|physics|chemistry|biology"
    "history:history|war|revolution|civilization"
    "philosophy:philosophy|ethics|logic|metaphysics"
    "gardening:gardening|plants|flowers|botanical"
    "farming:farming|agriculture|livestock|crops"
    "electronics:electronics|circuits|electrical|radio"
    "mechanics:mechanics|engines|mechanical|machines"
    "programming:programming|computer|algorithm"
    "survival:survival|wilderness|outdoor|emergency"
    "fiction:fiction|novel|story|tales"
    "poetry:poetry|poems|verse|rhyme"
    "drama:drama|play|theatre|tragedy"
    "cooking:cooking|recipe|food|culinary"
    "art:art|painting|sculpture|drawing"
    "music:music|song|melody|musical"
    "religion:religion|spiritual|divine|sacred"
    "medicine:medicine|medical|health|anatomy"
    "law:law|legal|justice|courts"
    "education:education|teaching|learning|school"
)

# Initialize files
CATALOG_FILE="$STORAGE_DIR/catalog.csv"
LOG_FILE="$STORAGE_DIR/logs/download.log"
STATS_FILE="$STORAGE_DIR/logs/stats.json"
FAILED_LOG="$STORAGE_DIR/logs/failed.csv"

# Use regular arrays instead of associative arrays
TOPIC_PATTERNS=(
    "mathematics:math|algebra|geometry|calculus"
    "science:science|physics|chemistry|biology"
    "history:history|war|revolution|civilization"
    "philosophy:philosophy|ethics|logic|metaphysics"
    "gardening:gardening|plants|flowers|botanical"
    "farming:farming|agriculture|livestock|crops"
    "electronics:electronics|circuits|electrical|radio"
    "mechanics:mechanics|engines|mechanical|machines"
    "programming:programming|computer|algorithm"
    "survival:survival|wilderness|outdoor|emergency"
    "fiction:fiction|novel|story|tales"
    "poetry:poetry|poems|verse|rhyme"
    "drama:drama|play|theatre|tragedy"
    "cooking:cooking|recipe|food|culinary"
    "art:art|painting|sculpture|drawing"
    "music:music|song|melody|musical"
    "religion:religion|spiritual|divine|sacred"
    "medicine:medicine|medical|health|anatomy"
    "law:law|legal|justice|courts"
    "education:education|teaching|learning|school"
)

# Function to get topic from subject
get_topic() {
    local subject=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    for topic_pattern in "${TOPIC_PATTERNS[@]}"; do
        local topic=${topic_pattern%%:*}
        local pattern=${topic_pattern#*:}
        if echo "$subject" | grep -qE "$pattern"; then
            echo "$topic"
            return 0
        fi
    done
    echo "other"
    return 0
}

# Function to test mirror speed
test_mirror_speed() {
    local mirror="$1"
    local test_file="1/pg1.txt"
    local start_time end_time duration
    
    echo -n "Testing $mirror... "
    start_time=$(date +%s.%N)
    if curl -s --head "${mirror}/${test_file}" | grep -q "200 OK"; then
        end_time=$(date +%s.%N)
        duration=$(echo "$end_time - $start_time" | bc)
        echo -e "${GREEN}OK${NC} (${duration}s)"
        echo "$duration $mirror"
    else
        echo -e "${RED}Failed${NC}"
        echo "999999 $mirror"
    fi
}

# Function to update statistics
update_stats() {
    local total="$1"
    local current="$2"
    local epub_count="$3"
    local txt_count="$4"
    local failed="$5"
    
    # Calculate percentages
    local progress=$((current * 100 / total))
    local success=$((epub_count + txt_count))
    local success_rate=$((success * 100 / current))
    
    # Create statistics JSON
    cat > "$STATS_FILE" << EOF
{
    "total": $total,
    "processed": $current,
    "progress": $progress,
    "epub_count": $epub_count,
    "txt_count": $txt_count,
    "failed": $failed,
    "success_rate": $success_rate,
    "topics": {
EOF
    
    # Add topic statistics
    local first=true
    for topic in "${!TOPICS[@]}"; do
        local count=$(find "$STORAGE_DIR/books/$topic" -type f 2>/dev/null | wc -l)
        if [ "$first" = true ]; then
            first=false
        else
            echo "," >> "$STATS_FILE"
        fi
        echo "        \"$topic\": $count" >> "$STATS_FILE"
    done
    
    echo "    }" >> "$STATS_FILE"
    echo "}" >> "$STATS_FILE"
    
    # Print progress
    echo -e "\n${YELLOW}Progress: $current/$total ($progress%)${NC}"
    echo -e "EPUB: $epub_count | TXT: $txt_count | Failed: $failed"
    echo -e "Success Rate: $success_rate%\n"
}

# Function to download catalog with better error handling
download_catalog() {
    local output_file="$1"
    local downloaded=0
    
    echo -e "\n${YELLOW}Attempting to download catalog from multiple sources...${NC}"
    
    for source in "${CATALOG_SOURCES[@]}"; do
        echo -e "Trying: $source"
        
        if curl -m 300 --retry 3 --retry-delay 5 -s "$source" -o "$output_file.tmp"; then
            if [ -s "$output_file.tmp" ]; then
                if head -n 1 "$output_file.tmp" | grep -q "Text#\|Title\|Author"; then
                    mv "$output_file.tmp" "$output_file"
                    echo -e "${GREEN}Successfully downloaded catalog from $source${NC}"
                    downloaded=1
                    
                    # Cache the successful download
                    mkdir -p "$STORAGE_DIR/cache"
                    cp "$output_file" "$STORAGE_DIR/cache/pg_catalog_cache.csv"
                    echo -e "${GREEN}Cached catalog for future use${NC}"
                    
                    return 0
                else
                    echo -e "${RED}Downloaded file appears invalid (wrong format)${NC}"
                fi
            else
                echo -e "${RED}Downloaded file is empty${NC}"
            fi
            rm -f "$output_file.tmp"
        else
            echo -e "${RED}Failed to download from $source${NC}"
        fi
    done
    
    # Try to use cached catalog if download failed
    local cache_file="$STORAGE_DIR/cache/pg_catalog_cache.csv"
    if [ -f "$cache_file" ] && [ -s "$cache_file" ]; then
        echo -e "${YELLOW}Using cached catalog from: $cache_file${NC}"
        cp "$cache_file" "$output_file"
        return 0
    fi
    
    echo -e "${RED}Failed to obtain catalog from any source${NC}"
    return 1
}

# Function to parse catalog
parse_catalog() {
    local input_file="$1"
    local output_file="$2"
    local total_lines=$(wc -l < "$input_file")
    local processed=0
    
    echo -e "\n${YELLOW}Parsing catalog entries...${NC}"
    
    # Create temporary directory for processing
    local temp_dir=$(mktemp -d)
    local chunk_size=1000
    local chunk_number=0
    
    # Split catalog into chunks for parallel processing
    split -l $chunk_size "$input_file" "$temp_dir/chunk_"
    
    # Process each chunk
    for chunk in "$temp_dir"/chunk_*; do
        ((chunk_number++))
        echo -e "Processing chunk $chunk_number..."
        
        while IFS=, read -r id title author subject language; do
            ((processed++))
            
            # Show progress every 1000 entries
            if ((processed % 1000 == 0)); then
                echo -e "${GREEN}Processed $processed of $total_lines entries${NC}"
            fi
            
            # Clean up fields
            title=$(echo "$title" | tr -d '"' | sed 's/^\s*//;s/\s*$//')
            author=$(echo "$author" | tr -d '"' | sed 's/^\s*//;s/\s*$//')
            subject=$(echo "$subject" | tr -d '"' | sed 's/^\s*//;s/\s*$//')
            
            # Skip if any required field is empty
            [ -z "$id" ] || [ -z "$title" ] || [ -z "$author" ] && continue
            
            # Write valid entries
            echo "$id,$title,$author,$subject,$language" >> "$output_file"
        done < "$chunk"
    done
    
    # Cleanup
    rm -rf "$temp_dir"
    
    # Verify results
    local valid_entries=$(wc -l < "$output_file")
    echo -e "\n${GREEN}Found $valid_entries valid books to process${NC}"
    
    return 0
}

# Progress bar function
progress_bar() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((percentage * width / 100))
    local empty=$((width - filled))
    
    printf "\rProgress: ["
    printf "%${filled}s" '' | tr ' ' '█'
    printf "%${empty}s" '' | tr ' ' '░'
    printf "] %3d%% (%d/%d)" "$percentage" "$current" "$total"
}

# Speed calculation function
calculate_speed() {
    local start_time=$1
    local current=$2
    local total=$3
    
    local current_time=$(date +%s)
    local elapsed=$((current_time - start_time))
    local speed=0
    local eta=0
    
    if [ $elapsed -gt 0 ]; then
        speed=$(echo "scale=2; $current / $elapsed" | bc)
        remaining=$((total - current))
        eta=$(echo "scale=0; $remaining / $speed" | bc 2>/dev/null || echo "calculating...")
    fi
    
    echo "$speed:$eta"
}

# Parallel download function using GNU Parallel if available
parallel_download() {
    local book_ids=("$@")
    local jobs=5  # Number of concurrent downloads
    
    if command -v parallel >/dev/null; then
        printf "%s\n" "${book_ids[@]}" | parallel -j $jobs download_single_book
    else
        for id in "${book_ids[@]}"; do
            download_single_book "$id"
        done
    fi
}

# Single book download function
download_single_book() {
    local id="$1"
    local mirror="$2"
    local output_dir="$3"
    
    # Try EPUB first with shorter timeout
    curl -m 30 -s "$mirror/$id/pg$id.epub" -o "$output_dir/$id.epub" && return 0
    
    # Try TXT if EPUB fails
    curl -m 30 -s "$mirror/$id/pg$id.txt" -o "$output_dir/$id.txt" && return 0
    
    return 1
}

# Main processing function with improved progress
process_books() {
    local catalog_file="$1"
    local start_time=$(date +%s)
    local batch_size=10
    local batch=()
    local processed=0
    local total=$(wc -l < "$catalog_file")
    
    echo -e "\n${YELLOW}Starting download process with parallel processing${NC}"
    echo -e "Using batch size: $batch_size"
    
    while IFS=, read -r id title author subject language; do
        [ "$id" = "Text#" ] && continue
        ((processed++))
        
        # Add to current batch
        batch+=("$id")
        
        # Process batch when full
        if [ ${#batch[@]} -eq $batch_size ]; then
            parallel_download "${batch[@]}"
            batch=()
            
            # Calculate speed and ETA
            local speed_eta=$(calculate_speed "$start_time" "$processed" "$total")
            local speed=${speed_eta%:*}
            local eta=${speed_eta#*:}
            
            # Clear line and show progress
            echo -en "\033[2K"  # Clear line
            progress_bar "$processed" "$total"
            printf " | %.2f books/s | ETA: %ss" "$speed" "$eta"
            
            # Show detailed stats every 100 books
            if ((processed % 100 == 0)); then
                echo -e "\n${GREEN}Statistics:${NC}"
                echo "EPUB: $epub_count | TXT: $txt_count | Failed: $failed"
                echo "Storage used: $(du -h "$STORAGE_DIR" | tail -n1 | cut -f1)"
                echo -e "Time elapsed: $(($(date +%s) - start_time))s\n"
            fi
        fi
    done < "$catalog_file"
    
    # Process remaining books in last batch
    if [ ${#batch[@]} -gt 0 ]; then
        parallel_download "${batch[@]}"
    fi
}

# Update main function
main() {
    echo -e "${GREEN}Starting Gutenberg Download Script${NC}"
    
    # Create directories
    for topic in "${!TOPICS[@]}"; do
        mkdir -p "$STORAGE_DIR/books/$topic"
    done
    mkdir -p "$STORAGE_DIR/logs"
    
    # Initialize catalog
    echo "ID,Title,Author,Subject,Filename,Format,Date,Path,Topic" > "$CATALOG_FILE"
    echo "ID,Title,Author,Reason,Date" > "$FAILED_LOG"
    
    # Test mirrors
    echo -e "\n${YELLOW}Testing mirrors...${NC}"
    declare -a working_mirrors
    while read -r speed mirror; do
        [ "$speed" = "999999" ] && continue
        working_mirrors+=("$mirror")
    done < <(
        for mirror in "${MIRRORS[@]}"; do
            test_mirror_speed "$mirror"
        done | sort -n
    )
    
    if [ ${#working_mirrors[@]} -eq 0 ]; then
        echo -e "${RED}No working mirrors found${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Found ${#working_mirrors[@]} working mirrors${NC}"
    
    # Download and process catalog
    local catalog_file="$STORAGE_DIR/catalog/pg_catalog.csv"
    local processed_catalog="$STORAGE_DIR/catalog/processed_catalog.csv"
    mkdir -p "$STORAGE_DIR/catalog"
    
    if ! download_catalog "$catalog_file"; then
        echo -e "${RED}Failed to obtain catalog from any source${NC}"
        exit 1
    fi
    
    if ! parse_catalog "$catalog_file" "$processed_catalog"; then
        echo -e "${RED}Failed to parse catalog${NC}"
        exit 1
    fi
    
    # Use processed catalog for downloads
    local total=$(wc -l < "$processed_catalog")
    echo -e "${GREEN}Ready to process $total books${NC}"
    
    # Initialize counters
    local current=0
    local epub_count=0
    local txt_count=0
    local failed=0
    
    # Process books with improved progress reporting
    echo -e "\n${YELLOW}Processing $total books...${NC}"
    process_books "$processed_catalog"
    
    # Show final statistics with colorful summary
    echo -e "\n${GREEN}Download Complete!${NC}"
    echo -e "${YELLOW}Final Statistics:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Total books processed: $total"
    echo "EPUB files: $epub_count"
    echo "TXT files: $txt_count"
    echo "Failed downloads: $failed"
    echo "Success rate: $(( (epub_count + txt_count) * 100 / total ))%"
    echo "Total time: $(( $(date +%s) - start_time ))s"
    echo "Average speed: $(echo "scale=2; $total / $(( $(date +%s) - start_time ))" | bc) books/s"
    echo "Total storage used: $(du -h "$STORAGE_DIR" | tail -n1 | cut -f1)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Generate topic statistics
    echo -e "\n${YELLOW}Books by Topic:${NC}"
    for topic in "${!TOPICS[@]}"; do
        count=$(find "$STORAGE_DIR/books/$topic" -type f 2>/dev/null | wc -l)
        printf "%-15s: %5d books\n" "$topic" "$count"
    done
}

# Run main process
main 