#!/bin/bash

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS configuration
    STORAGE_DIR="$HOME/Desktop/Storage/Books"
else
    # Linux configuration
    STORAGE_DIR="/home/storage/Books"
fi

LOG_FILE="$STORAGE_DIR/logs/gutenberg_download.log"
CATALOG_FILE="$STORAGE_DIR/catalog.csv"

# Add tracking for failed books
FAILED_BOOKS_LOG="$STORAGE_DIR/logs/failed_books.csv"

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

# Retry configuration
MAX_RETRIES=3
RETRY_DELAY=5

# Function to log messages
log_message() {
    echo -e "$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to create storage directory structure
create_storage_dirs() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        mkdir -p "$STORAGE_DIR"/{books,logs,catalog}
        chmod -R 755 "$STORAGE_DIR"
        
        # Create a README file
        cat > "$STORAGE_DIR/README.md" << EOF
# Gutenberg Library Collection
This directory contains downloaded books from Project Gutenberg.
EOF
    else
        sudo mkdir -p "$STORAGE_DIR"/{books,logs,catalog}
        sudo chown -R $USER:users "$STORAGE_DIR"
        sudo chmod -R 775 "$STORAGE_DIR"
    fi
}

# Function to analyze book content and metadata
analyze_book() {
    local book_id="$1"
    local title="$2"
    local author="$3"
    local subject="$4"
    local metadata_url="https://www.gutenberg.org/ebooks/$book_id"
    local txt_url="https://www.gutenberg.org/cache/epub/$book_id/pg$book_id.txt"
    
    # Create temporary file
    local temp_file=$(mktemp)
    
    # Try to get metadata
    if curl -s "$metadata_url" > "$temp_file"; then
        # Extract additional subjects and keywords from metadata
        local extra_subjects=$(grep -i "subject:" "$temp_file" | sed 's/.*subject://i' | tr ',' '\n')
        subject="$subject $extra_subjects"
    fi
    
    # Try to get first 1000 lines of text for analysis
    if curl -s "$txt_url" | head -n 1000 > "$temp_file"; then
        # Look for topic indicators in content
        if grep -qi "theorem\|proof\|equation\|mathematical" "$temp_file"; then
            echo "mathematics"
        elif grep -qi "experiment\|scientific\|laboratory\|observation" "$temp_file"; then
            echo "science"
        elif grep -qi "battle\|war\|kingdom\|empire\|century\|historical" "$temp_file"; then
            echo "history"
        elif grep -qi "philosophy\|wisdom\|ethics\|moral\|metaphysics" "$temp_file"; then
            echo "philosophy"
        elif grep -qi "garden\|plant\|flower\|soil\|cultivation" "$temp_file"; then
            echo "gardening"
        elif grep -qi "farm\|crop\|livestock\|agriculture" "$temp_file"; then
            echo "farming"
        elif grep -qi "circuit\|electricity\|voltage\|electronic" "$temp_file"; then
            echo "electronics"
        elif grep -qi "engine\|machine\|mechanical\|mechanism" "$temp_file"; then
            echo "mechanics"
        elif grep -qi "program\|algorithm\|computation\|computer" "$temp_file"; then
            echo "programming"
        elif grep -qi "survival\|wilderness\|outdoor\|nature" "$temp_file"; then
            echo "survival"
        elif grep -qi "fiction\|novel\|story\|tale" "$temp_file"; then
            echo "fiction"
        elif grep -qi "poetry\|poem\|verse\|rhyme" "$temp_file"; then
            echo "poetry"
        elif grep -qi "play\|drama\|theatre\|act" "$temp_file"; then
            echo "drama"
        elif grep -qi "cook\|recipe\|food\|kitchen" "$temp_file"; then
            echo "cooking"
        elif grep -qi "art\|paint\|sculpture\|artist" "$temp_file"; then
            echo "art"
        elif grep -qi "music\|song\|melody\|musical" "$temp_file"; then
            echo "music"
        elif grep -qi "religion\|spiritual\|divine\|sacred" "$temp_file"; then
            echo "religion"
        elif grep -qi "medicine\|medical\|health\|disease" "$temp_file"; then
            echo "medicine"
        elif grep -qi "law\|legal\|justice\|court" "$temp_file"; then
            echo "law"
        elif grep -qi "education\|teaching\|learning\|school" "$temp_file"; then
            echo "education"
        else
            # Fallback to subject-based categorization
            local subject_lower=$(echo "$subject" | tr '[:upper:]' '[:lower:]')
            if echo "$subject_lower" | grep -q "science\|physics\|chemistry\|biology"; then
                echo "science"
            elif echo "$subject_lower" | grep -q "math\|algebra\|geometry"; then
                echo "mathematics"
            elif echo "$subject_lower" | grep -q "history\|historical"; then
                echo "history"
            elif echo "$subject_lower" | grep -q "philosophy"; then
                echo "philosophy"
            else
                echo "other"
            fi
        fi
    else
        # Fallback to title-based categorization
        local title_lower=$(echo "$title" | tr '[:upper:]' '[:lower:]')
        case "$title_lower" in
            *theorem*|*mathematics*|*algebra*) echo "mathematics" ;;
            *history*|*chronicle*|*war*) echo "history" ;;
            *philosophy*|*ethics*) echo "philosophy" ;;
            *garden*|*flower*) echo "gardening" ;;
            *farm*|*agriculture*) echo "farming" ;;
            *electronic*|*electricity*) echo "electronics" ;;
            *engine*|*machine*) echo "mechanics" ;;
            *program*|*computer*) echo "programming" ;;
            *survival*|*wilderness*) echo "survival" ;;
            *novel*|*story*) echo "fiction" ;;
            *poem*|*poetry*) echo "poetry" ;;
            *play*|*drama*) echo "drama" ;;
            *cook*|*recipe*) echo "cooking" ;;
            *art*|*paint*) echo "art" ;;
            *music*|*song*) echo "music" ;;
            *religion*|*spiritual*) echo "religion" ;;
            *medicine*|*medical*) echo "medicine" ;;
            *law*|*legal*) echo "law" ;;
            *education*|*teaching*) echo "education" ;;
            *) echo "other" ;;
        esac
    fi
    
    # Cleanup
    rm -f "$temp_file"
}

# Function to test mirror speed
test_mirror_speed() {
    local mirror="$1"
    local test_file="1/pg1.txt"  # Small file for testing
    local start_time end_time duration
    
    # Test download speed
    start_time=$(date +%s.%N)
    if curl -s "${mirror}/${test_file}" -o /dev/null; then
        end_time=$(date +%s.%N)
        duration=$(echo "$end_time - $start_time" | bc)
        echo "$duration $mirror"
    else
        echo "999999 $mirror"  # Large number for failed mirrors
    fi
}

# Function to sort mirrors by speed
sort_mirrors() {
    log_message "${YELLOW}Testing mirror speeds...${NC}"
    local temp_file=$(mktemp)
    
    # Test each mirror
    for mirror in "${MIRRORS[@]}"; do
        log_message "Testing: $mirror"
        test_mirror_speed "$mirror" >> "$temp_file"
    done
    
    # Sort mirrors by speed and store in array
    SORTED_MIRRORS=()
    while read -r speed mirror; do
        if [ "$speed" != "999999" ]; then
            SORTED_MIRRORS+=("$mirror")
            log_message "${GREEN}Mirror: $mirror - Speed: ${speed}s${NC}"
        else
            log_message "${RED}Mirror failed: $mirror${NC}"
        fi
    done < <(sort -n "$temp_file")
    
    # Cleanup
    rm -f "$temp_file"
    
    # If no mirrors are responsive, exit
    if [ ${#SORTED_MIRRORS[@]} -eq 0 ]; then
        log_message "${RED}No responsive mirrors found${NC}"
        exit 1
    fi
    
    log_message "${GREEN}Using fastest mirror: ${SORTED_MIRRORS[0]}${NC}"
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

# Function to handle retries
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

# Function to download a book with retries
download_book() {
    local book_id="$1"
    local title="$2"
    local author="$3"
    local subject="$4"
    
    # Determine topic through analysis
    local topic=$(analyze_book "$book_id" "$title" "$author" "$subject")
    local output_dir="$STORAGE_DIR/books/$topic"
    
    mkdir -p "$output_dir"
    
    # Sanitize filename
    local safe_title=$(echo "$title" | tr -cd '[:alnum:] ._-' | tr ' ' '_')
    local safe_author=$(echo "$author" | tr -cd '[:alnum:] ._-' | tr ' ' '_')
    
    # Try EPUB from fastest mirror first
    log_message "${YELLOW}Checking for EPUB version of: $title (Topic: $topic)${NC}"
    for mirror in "${SORTED_MIRRORS[@]}"; do
        local url="${mirror}/${book_id}/pg${book_id}.epub"
        local filename="${book_id}_${safe_author}_${safe_title}.epub"
        local full_path="$output_dir/$filename"
        
        if curl -s --head "$url" | head -n 1 | grep "HTTP/1.[01] [23].*" > /dev/null; then
            log_message "Downloading EPUB from $mirror"
            
            if retry_download "$url" "$full_path"; then
                log_message "${GREEN}Successfully downloaded EPUB: $filename${NC}"
                log_message "${GREEN}Location: $full_path${NC}"
                echo "$book_id,$title,$author,$topic,$filename,epub,$(date '+%Y-%m-%d'),$full_path,$language" >> "$CATALOG_FILE"
                return 0
            fi
        fi
    done
    
    # If no EPUB found, try TXT with retries
    log_message "${YELLOW}No EPUB found, trying TXT version...${NC}"
    for mirror in "${SORTED_MIRRORS[@]}"; do
        local url="${mirror}/${book_id}/pg${book_id}.txt"
        local filename="${book_id}_${safe_author}_${safe_title}.txt"
        local full_path="$output_dir/$filename"
        
        if curl -s --head "$url" | head -n 1 | grep "HTTP/1.[01] [23].*" > /dev/null; then
            log_message "Downloading TXT from $mirror"
            
            if retry_download "$url" "$full_path"; then
                log_message "${YELLOW}Successfully downloaded TXT: $filename${NC}"
                log_message "${YELLOW}Location: $full_path${NC}"
                echo "$book_id,$title,$author,$topic,$filename,txt,$(date '+%Y-%m-%d'),$full_path,$language" >> "$CATALOG_FILE"
                return 0
            fi
        fi
    done
    
    log_failed_book "$book_id" "$title" "$author" "Failed after $MAX_RETRIES retries"
    log_message "${RED}Failed to download book ID: $book_id after all retries${NC}"
    return 1
}

# Function to create topic-specific index
create_topic_index() {
    local topic="$1"
    local topic_dir="$STORAGE_DIR/books/$topic"
    local index_file="$topic_dir/index.html"
    
    cat > "$index_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>$topic Books</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .book { margin-bottom: 20px; padding: 10px; border: 1px solid #ccc; }
        .title { font-weight: bold; }
        .author { color: #666; }
        .path { font-family: monospace; font-size: 0.9em; color: #888; }
        .format { color: #009900; }
    </style>
</head>
<body>
    <h1>$topic Books</h1>
EOF
    
    # Filter catalog for this topic
    while IFS=, read -r id title author book_topic filename date path; do
        [[ "$id" == "ID" || "$book_topic" != "$topic" ]] && continue
        local format="${filename##*.}"
        cat >> "$index_file" << EOF
    <div class="book">
        <div class="title">$title</div>
        <div class="author">by $author</div>
        <div class="format">Format: ${format}</div>
        <div class="path">Location: $path</div>
        <div>Added: $date</div>
    </div>
EOF
    done < "$CATALOG_FILE"
    
    echo "</body></html>" >> "$index_file"
}

# Function to create main index with topic links
create_main_index() {
    local index_file="$STORAGE_DIR/index.html"
    
    cat > "$index_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Gutenberg Library Index</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .topic { margin-bottom: 20px; }
        .topic-name { font-size: 1.2em; font-weight: bold; margin-bottom: 10px; }
        .book-count { color: #666; }
    </style>
</head>
<body>
    <h1>Gutenberg Library Index</h1>
EOF
    
    for topic_entry in "${TOPICS[@]}"; do
        IFS=':' read -r topic keywords <<< "$topic_entry"
        local count=$(grep -c ",$topic," "$CATALOG_FILE")
        cat >> "$index_file" << EOF
    <div class="topic">
        <div class="topic-name">$topic</div>
        <div class="book-count">$count books</div>
        <a href="books/$topic/index.html">View $topic books</a>
    </div>
EOF
    done
    
    echo "</body></html>" >> "$index_file"
}

# Function to get topic keywords
get_topic_keywords() {
    local topic="$1"
    for t in "${TOPICS[@]}"; do
        IFS=':' read -r name keywords <<< "$t"
        if [ "$name" = "$topic" ]; then
            echo "$keywords"
            return 0
        fi
    done
}

# Function to process catalog
process_catalog() {
    local catalog_url="https://www.gutenberg.org/cache/epub/feeds/pg_catalog.csv"
    local catalog_file="$STORAGE_DIR/catalog/pg_catalog.csv"
    
    log_message "Downloading Gutenberg catalog..."
    mkdir -p "$STORAGE_DIR/catalog"
    
    if ! curl -s -o "$catalog_file" "$catalog_url"; then
        log_message "${RED}Failed to download catalog - retrying...${NC}"
        sleep 5
        if ! curl -s -o "$catalog_file" "$catalog_url"; then
            log_message "${RED}Failed to download catalog after retry${NC}"
            exit 1
        fi
    fi
    
    # Check if catalog was downloaded successfully
    if [ ! -s "$catalog_file" ]; then
        log_message "${RED}Catalog file is empty - possible network issue${NC}"
        exit 1
    fi
    
    log_message "${GREEN}Catalog downloaded successfully${NC}"
    
    # Initialize catalog with headers
    echo "ID,Title,Author,Subject,Filename,Format,Date_Added,Full_Path,Language" > "$CATALOG_FILE"
    
    # Initialize counters
    local total=0
    local success=0
    local epub_count=0
    local txt_count=0
    
    # Create temporary files for language statistics
    local lang_stats_file=$(mktemp)
    
    # Process all books
    while IFS=$'\n' read -r line; do
        [ -z "$line" ] && continue
        
        # Parse CSV line
        id=$(echo "$line" | cut -d',' -f1)
        title=$(echo "$line" | cut -d',' -f2)
        author=$(echo "$line" | cut -d',' -f3)
        subject=$(echo "$line" | cut -d',' -f4)
        language=$(echo "$line" | cut -d',' -f5)
        
        [ "$id" = "Text#" ] && continue
        
        ((total++))
        
        # Clean up fields
        title=$(echo "$title" | tr -d '"' | sed 's/^\s*//;s/\s*$//')
        author=$(echo "$author" | tr -d '"' | sed 's/^\s*//;s/\s*$//')
        subject=$(echo "$subject" | tr -d '"' | sed 's/^\s*//;s/\s*$//')
        language=$(echo "$language" | tr -d '"' | sed 's/^\s*//;s/\s*$//')
        
        # Update language stats file
        echo "$language" >> "$lang_stats_file"
        
        # Show detailed progress
        printf "\r\033[K" # Clear line
        echo -e "${YELLOW}Processing book $total${NC}"
        echo -e "Title: $title"
        echo -e "Author: $author"
        echo -e "Language: $language"
        
        if download_book "$id" "$title" "$author" "$subject"; then
            ((success++))
            if grep -q "epub" <<< "$CATALOG_FILE"; then
                ((epub_count++))
            else
                ((txt_count++))
            fi
            
            # Show progress every 25 books
            if ((success % 25 == 0)); then
                clear
                echo -e "${GREEN}=== Download Progress ===${NC}"
                echo -e "Total processed: $total"
                echo -e "Successfully downloaded: $success"
                echo -e "EPUB files: $epub_count"
                echo -e "TXT files: $txt_count"
                echo -e "\n${YELLOW}Language Statistics:${NC}"
                sort "$lang_stats_file" | uniq -c | sort -rn | while read -r count lang; do
                    echo -e "$lang: $count"
                done
                echo -e "\n${GREEN}Success rate: $((success * 100 / total))%${NC}"
            fi
        else
            log_message "${RED}Failed to download: $title${NC}"
        fi
        
    done < "$catalog_file"
    
    # Final statistics
    clear
    log_message "${GREEN}Download complete!${NC}"
    echo -e "\n${GREEN}=== Final Statistics ===${NC}"
    echo -e "Total books processed: $total"
    echo -e "Successfully downloaded: $success"
    echo -e "EPUB files: $epub_count"
    echo -e "TXT files: $txt_count"
    echo -e "Success rate: $((success * 100 / total))%"
    
    echo -e "\n${YELLOW}Language Statistics:${NC}"
    sort "$lang_stats_file" | uniq -c | sort -rn | while read -r count lang; do
        echo -e "$lang: $count books ($((count * 100 / total))%)"
    done
    
    # Generate enhanced index with the language stats
    generate_enhanced_index "$total" "$success" "$epub_count" "$txt_count" "$lang_stats_file"
    
    # Cleanup
    rm -f "$lang_stats_file"
}

# Function to get storage statistics
get_storage_stats() {
    local base_dir="$1"
    local total_size=0
    local epub_size=0
    local txt_size=0
    local stats_file=$(mktemp)
    
    echo "Calculating storage statistics..."
    
    # Get sizes in bytes
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        total_size=$(du -k "$base_dir" | tail -1 | cut -f1)
        epub_size=$(find "$base_dir" -name "*.epub" -exec du -k {} + 2>/dev/null | awk '{sum += $1} END {print sum}')
        txt_size=$(find "$base_dir" -name "*.txt" -exec du -k {} + 2>/dev/null | awk '{sum += $1} END {print sum}')
    else
        # Linux
        total_size=$(du -b "$base_dir" | tail -1 | cut -f1)
        epub_size=$(find "$base_dir" -name "*.epub" -exec du -b {} + 2>/dev/null | awk '{sum += $1} END {print sum}')
        txt_size=$(find "$base_dir" -name "*.txt" -exec du -b {} + 2>/dev/null | awk '{sum += $1} END {print sum}')
    fi
    
    # Convert to human-readable format
    local hr_total=$(numfmt --to=iec-i --suffix=B "$total_size")
    local hr_epub=$(numfmt --to=iec-i --suffix=B "$epub_size")
    local hr_txt=$(numfmt --to=iec-i --suffix=B "$txt_size")
    
    # Get per-topic statistics
    echo "Topic,Size,Files" > "$stats_file"
    for topic in "$base_dir"/books/*; do
        if [ -d "$topic" ]; then
            local topic_name=$(basename "$topic")
            local topic_size=0
            local file_count=0
            
            if [[ "$OSTYPE" == "darwin"* ]]; then
                topic_size=$(du -k "$topic" | tail -1 | cut -f1)
                file_count=$(find "$topic" -type f | wc -l | tr -d ' ')
            else
                topic_size=$(du -b "$topic" | tail -1 | cut -f1)
                file_count=$(find "$topic" -type f | wc -l | tr -d ' ')
            fi
            
            local hr_topic_size=$(numfmt --to=iec-i --suffix=B "$topic_size")
            echo "$topic_name,$hr_topic_size,$file_count" >> "$stats_file"
        fi
    done
    
    echo "$total_size:$hr_total:$epub_size:$hr_epub:$txt_size:$hr_txt:$stats_file"
}

# Function to create ASCII bar chart
create_ascii_chart() {
    local -n data=$1
    local title="$2"
    local max_label_length=0
    local max_value=0
    
    # Find maximum values
    for key in "${!data[@]}"; do
        (( ${#key} > max_label_length )) && max_label_length=${#key}
        (( ${data[$key]} > max_value )) && max_value=${data[$key]}
    done
    
    # Print chart
    echo -e "\n$title"
    echo -e "─"$(printf '%.0s─' $(seq 1 $((max_label_length + 52))))"─"
    
    for key in "${!data[@]}"; do
        local value=${data[$key]}
        local bar_length=$(( value * 50 / max_value ))
        printf "%-${max_label_length}s │ %4d │ " "$key" "$value"
        printf '%.0s█' $(seq 1 $bar_length)
        echo
    done
    
    echo -e "─"$(printf '%.0s─' $(seq 1 $((max_label_length + 52))))"─"
}

# Function to generate SVG charts
generate_svg_charts() {
    local stats_dir="$STORAGE_DIR/stats"
    mkdir -p "$stats_dir"
    
    # Generate format distribution pie chart
    cat > "$stats_dir/format_distribution.svg" << EOF
<svg width="400" height="400" xmlns="http://www.w3.org/2000/svg">
    <script type="text/javascript"><![CDATA[
        // Add interactive tooltips
        function showTooltip(evt, text) {
            let tooltip = document.getElementById("tooltip");
            tooltip.innerHTML = text;
            tooltip.style.display = "block";
            tooltip.style.left = evt.pageX + 10 + 'px';
            tooltip.style.top = evt.pageY + 10 + 'px';
        }
        
        function hideTooltip() {
            var tooltip = document.getElementById("tooltip");
            tooltip.style.display = "none";
        }
    ]]></script>
    
    <style>
        .chart-title { font-family: Arial; font-size: 20px; }
        .slice { transition: all .2s ease-in-out; }
        .slice:hover { transform: scale(1.05); }
    </style>
    
    <title>Format Distribution</title>
    
    <!-- Add chart elements here -->
</svg>
EOF
    
    # Generate topic distribution bar chart
    cat > "$stats_dir/topic_distribution.svg" << EOF
<svg width="800" height="400" xmlns="http://www.w3.org/2000/svg">
    <style>
        .bar { transition: all .2s ease-in-out; }
        .bar:hover { opacity: 0.8; }
        .axis { font: 12px Arial; }
    </style>
    
    <title>Books by Topic</title>
    
    <!-- Add chart elements here -->
</svg>
EOF
    
    # Generate download progress line chart
    cat > "$stats_dir/download_progress.svg" << EOF
<svg width="800" height="400" xmlns="http://www.w3.org/2000/svg">
    <style>
        .line { fill: none; stroke: #2196F3; stroke-width: 2; }
        .point { fill: #2196F3; }
        .point:hover { fill: #ff4444; r: 6; }
    </style>
    
    <title>Download Progress</title>
    
    <!-- Add chart elements here -->
</svg>
EOF
}

# Function to generate enhanced index with storage stats
generate_enhanced_index() {
    local total="$1"
    local success="$2"
    local epub_count="$3"
    local txt_count="$4"
    local lang_stats_file="$5"
    local index_file="$STORAGE_DIR/index.html"
    
    # Get storage statistics
    IFS=':' read -r total_bytes hr_total epub_bytes hr_epub txt_bytes hr_txt stats_file <<< "$(get_storage_stats "$STORAGE_DIR")"
    
    cat > "$index_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Project Gutenberg Library</title>
    <style>
        :root {
            --primary-color: #2196F3;
            --secondary-color: #4CAF50;
            --warning-color: #FFC107;
            --error-color: #F44336;
            --background-color: #f5f5f5;
            --card-background: #ffffff;
        }
        
        body {
            font-family: 'Segoe UI', Arial, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: var(--background-color);
            color: #333;
            line-height: 1.6;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        
        h1, h2, h3 {
            color: var(--primary-color);
            margin-bottom: 1rem;
        }
        
        .card {
            background: var(--card-background);
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            padding: 20px;
            margin-bottom: 20px;
            transition: transform 0.2s ease-in-out;
        }
        
        .card:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 8px rgba(0,0,0,0.2);
        }
        
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin: 20px 0;
        }
        
        .stat-card {
            background: var(--card-background);
            padding: 15px;
            border-radius: 8px;
            text-align: center;
        }
        
        .stat-number {
            font-size: 2em;
            font-weight: bold;
            color: var(--primary-color);
        }
        
        .progress-bar {
            background: #e0e0e0;
            height: 20px;
            border-radius: 10px;
            overflow: hidden;
            margin: 10px 0;
        }
        
        .progress-fill {
            height: 100%;
            background: var(--primary-color);
            transition: width 0.3s ease-in-out;
        }
        
        .book {
            background: var(--card-background);
            padding: 15px;
            border-radius: 8px;
            margin-bottom: 15px;
            border-left: 4px solid var(--primary-color);
        }
        
        .book:hover {
            transform: translateX(5px);
        }
        
        .title {
            font-size: 1.2em;
            font-weight: bold;
            color: var(--primary-color);
        }
        
        .author {
            color: #666;
            font-style: italic;
        }
        
        .format {
            display: inline-block;
            padding: 3px 8px;
            border-radius: 4px;
            background: var(--secondary-color);
            color: white;
            font-size: 0.9em;
        }
        
        .visualizations {
            margin-top: 40px;
        }
        
        .chart-container {
            background: var(--card-background);
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 20px;
        }
        
        @media (max-width: 768px) {
            .stats {
                grid-template-columns: 1fr;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Project Gutenberg Library</h1>
        
        <div class="stats">
            <h2>Download Statistics</h2>
            <p>Total Books: $total</p>
            <p>Successfully Downloaded: $success</p>
            <p>EPUB files: $epub_count</p>
            <p>TXT files: $txt_count</p>
            <div class="progress">
                <p>Success Rate: $((success * 100 / total))%</p>
                <div class="progress-bar">
                    <div class="progress-fill" style="width: $((success * 100 / total))%;"></div>
                </div>
            </div>
        </div>
        
        <div class="storage-stats">
            <h2>Storage Statistics</h2>
            <p>Total Storage Used: $hr_total</p>
            <p>EPUB Files Size: $hr_epub</p>
            <p>TXT Files Size: $hr_txt</p>
            
            <h3>Storage by Topic</h3>
            <div class="topic-stats">
EOF
    
    # Add topic statistics
    while IFS=, read -r topic size files; do
        [ "$topic" = "Topic" ] && continue
        cat >> "$index_file" << EOF
                <div class="topic-card">
                    <h4>$topic</h4>
                    <p>Size: $size</p>
                    <p>Files: $files</p>
                </div>
EOF
    done < "$stats_file"
    
    # Continue with the rest of the index
    cat >> "$index_file" << EOF
            </div>
        </div>
        
        <h2>Book Collection</h2>
EOF
    
    # Add book listings
    while IFS=, read -r id title author subject filename format date path language; do
        [[ "$id" == "ID" ]] && continue
        cat >> "$index_file" << EOF
        <div class="book">
            <div class="title">$title</div>
            <div class="author">by $author</div>
            <div class="subject">Subject: $subject</div>
            <div class="format">Format: $format</div>
            <div class="language">Language: $language</div>
            <div>Added: $date</div>
            <div>Path: $path</div>
        </div>
EOF
    done < "$CATALOG_FILE"
    
    # Add visualization section
    cat >> "$index_file" << EOF
        <div class="visualizations">
            <h2>Data Visualizations</h2>
            
            <div class="chart-container">
                <h3>Format Distribution</h3>
                <object data="stats/format_distribution.svg" type="image/svg+xml" width="400" height="400"></object>
            </div>
            
            <div class="chart-container">
                <h3>Books by Topic</h3>
                <object data="stats/topic_distribution.svg" type="image/svg+xml" width="800" height="400"></object>
            </div>
            
            <div class="chart-container">
                <h3>Download Progress</h3>
                <object data="stats/download_progress.svg" type="image/svg+xml" width="800" height="400"></object>
            </div>
        </div>
    </div>
    
    <style>
        .visualizations { margin: 20px 0; }
        .chart-container { margin: 20px 0; padding: 20px; background: #f8f8f8; border-radius: 5px; }
        .tooltip { position: absolute; display: none; background: white; border: 1px solid #ccc; padding: 5px; border-radius: 3px; }
    </style>
    
    <div id="tooltip" class="tooltip"></div>
</body>
</html>
EOF
    
    # Cleanup
    rm -f "$stats_file"
}

# Function to analyze failed downloads
analyze_failed_books() {
    local failed_books_file="$1"
    
    if [ ! -f "$failed_books_file" ] || [ ! -s "$failed_books_file" ]; then
        echo -e "\n${YELLOW}No failed downloads recorded${NC}"
        return
    }
    
    local total_failed=$(( $(wc -l < "$failed_books_file") - 1 ))
    echo -e "\n${RED}Failed Downloads Analysis${NC}"
    echo -e "Total Failed: $total_failed"
    
    # Group by failure reason
    echo -e "\n${YELLOW}Failure Reasons:${NC}"
    tail -n +2 "$failed_books_file" | cut -d',' -f4 | sort | uniq -c | sort -rn | while read -r count reason; do
        echo -e "- $reason: $count occurrences"
    done
    
    # List failed books
    echo -e "\n${YELLOW}Failed Books:${NC}"
    awk -F',' 'NR>1 {gsub(/"/, "", $2); gsub(/"/, "", $3); printf "- %s by %s (ID: %s)\n", $2, $3, $1}' "$failed_books_file"
}

# Function to generate final statistics
generate_final_stats() {
    local base_dir="$1"
    local catalog_file="$2"
    
    echo -e "\n${GREEN}=== Final Library Statistics ===${NC}"
    
    # Storage statistics
    IFS=':' read -r total_bytes hr_total epub_bytes hr_epub txt_bytes hr_txt stats_file <<< "$(get_storage_stats "$base_dir")"
    echo -e "\n${YELLOW}Storage Statistics:${NC}"
    echo -e "Total Storage Used: $hr_total"
    echo -e "EPUB Files Size: $hr_epub"
    echo -e "TXT Files Size: $hr_txt"
    
    # Book count statistics
    local total_books=$(wc -l < "$catalog_file")
    local epub_count=$(grep -c "epub" "$catalog_file")
    local txt_count=$(grep -c "txt" "$catalog_file")
    echo -e "\n${YELLOW}Book Statistics:${NC}"
    echo -e "Total Books: $((total_books - 1))"  # Subtract header line
    echo -e "EPUB Format: $epub_count"
    echo -e "TXT Format: $txt_count"
    
    # Topic statistics
    echo -e "\n${YELLOW}Books by Topic:${NC}"
    for topic_dir in "$base_dir"/books/*; do
        if [ -d "$topic_dir" ]; then
            local topic=$(basename "$topic_dir")
            local count=$(find "$topic_dir" -type f | wc -l | tr -d ' ')
            local size=$(du -h "$topic_dir" | cut -f1)
            echo -e "$topic: $count books ($size)"
        fi
    done
    
    # Language statistics
    echo -e "\n${YELLOW}Books by Language:${NC}"
    awk -F',' 'NR>1 {print $9}' "$catalog_file" | sort | uniq -c | sort -rn | while read -r count lang; do
        echo -e "$lang: $count books"
    done
    
    # Mirror statistics
    echo -e "\n${YELLOW}Mirror Statistics:${NC}"
    for mirror in "${SORTED_MIRRORS[@]}"; do
        local speed=$(test_mirror_speed "$mirror" | cut -d' ' -f1)
        echo -e "Mirror: $mirror"
        echo -e "Response Time: ${speed}s"
    done
    
    # Calculate average file sizes
    local avg_epub_size=0
    local avg_txt_size=0
    if [ $epub_count -gt 0 ]; then
        avg_epub_size=$(echo "scale=2; $epub_bytes / $epub_count" | bc)
        avg_epub_size=$(numfmt --to=iec-i --suffix=B "$avg_epub_size")
    fi
    if [ $txt_count -gt 0 ]; then
        avg_txt_size=$(echo "scale=2; $txt_bytes / $txt_count" | bc)
        avg_txt_size=$(numfmt --to=iec-i --suffix=B "$avg_txt_size")
    fi
    
    echo -e "\n${YELLOW}Average File Sizes:${NC}"
    echo -e "Average EPUB Size: $avg_epub_size"
    echo -e "Average TXT Size: $avg_txt_size"
    
    # Success rate
    local success_rate=$(echo "scale=2; ($epub_count + $txt_count) * 100 / $total_books" | bc)
    echo -e "\n${YELLOW}Download Statistics:${NC}"
    echo -e "Success Rate: ${success_rate}%"
    
    # Add failed books analysis
    echo -e "\n${YELLOW}Failed Downloads:${NC}"
    analyze_failed_books "$FAILED_BOOKS_LOG"
    
    # Create ASCII charts for terminal output
    declare -A format_stats
    format_stats["EPUB"]=$epub_count
    format_stats["TXT"]=$txt_count
    create_ascii_chart format_stats "Format Distribution"
    
    declare -A topic_stats
    for topic_dir in "$STORAGE_DIR/books/"*; do
        if [ -d "$topic_dir" ]; then
            local topic=$(basename "$topic_dir")
            topic_stats[$topic]=$(find "$topic_dir" -type f | wc -l | tr -d ' ')
        fi
    done
    create_ascii_chart topic_stats "Books by Topic"
    
    # Generate SVG charts
    generate_svg_charts
    
    # Save statistics to file
    local stats_summary="$base_dir/statistics.txt"
    {
        echo "=== Project Gutenberg Library Statistics ==="
        echo "Generated: $(date)"
        echo ""
        echo "Storage Statistics:"
        echo "Total Storage: $hr_total"
        echo "EPUB Files: $hr_epub"
        echo "TXT Files: $hr_txt"
        echo ""
        echo "Book Statistics:"
        echo "Total Books: $((total_books - 1))"
        echo "EPUB Format: $epub_count"
        echo "TXT Format: $txt_count"
        echo ""
        echo "Average File Sizes:"
        echo "EPUB: $avg_epub_size"
        echo "TXT: $avg_txt_size"
        echo ""
        echo "Success Rate: ${success_rate}%"
        echo ""
        echo "Books by Topic:"
        for topic_dir in "$base_dir"/books/*; do
            if [ -d "$topic_dir" ]; then
                local topic=$(basename "$topic_dir")
                local count=$(find "$topic_dir" -type f | wc -l | tr -d ' ')
                local size=$(du -h "$topic_dir" | cut -f1)
                echo "$topic: $count books ($size)"
            fi
        done
        echo ""
        echo "Failed Downloads:"
        echo "Total Failed: $total_failed"
        echo ""
        echo "Failed Books List:"
        awk -F',' 'NR>1 {gsub(/"/, "", $2); gsub(/"/, "", $3); printf "%s by %s (ID: %s)\n", $2, $3, $1}' "$FAILED_BOOKS_LOG"
    } > "$stats_summary"
    
    echo -e "\n${GREEN}Statistics have been saved to: $stats_summary${NC}"
}

# Main function
main() {
    log_message "Starting Gutenberg download process..."
    
    # Create topic directories
    mkdir -p "$STORAGE_DIR/books"/{mathematics,science,history,philosophy,gardening,farming,electronics,mechanics,programming,survival,fiction,poetry,drama,cooking,art,music,religion,medicine,law,education,other}
    
    # Sort mirrors by speed
    sort_mirrors
    
    # Process catalog and download books
    process_catalog
    
    # Generate final statistics
    generate_final_stats "$STORAGE_DIR" "$CATALOG_FILE"
}

# Run main process
main 