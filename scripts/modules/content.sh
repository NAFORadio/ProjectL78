#!/bin/bash
# Content management module for offline library

source "$(dirname "$0")/../common/utils.sh"

# Define book collections by category
declare -A PHILOSOPHY_BOOKS=(
    ["1497"]="The Republic by Plato"
    ["2130"]="Meditations by Marcus Aurelius"
    ["8438"]="Nicomachean Ethics by Aristotle"
    ["4280"]="Critique of Pure Reason by Kant"
    ["5827"]="Thus Spoke Zarathustra by Nietzsche"
    ["7400"]="Beyond Good and Evil by Nietzsche"
    ["3207"]="Leviathan by Hobbes"
    ["3600"]="Essay Concerning Human Understanding by Locke"
)

declare -A SCIENCE_BOOKS=(
    ["1228"]="Origin of Species by Darwin"
    ["37729"]="Relativity: The Special and General Theory by Einstein"
    ["4216"]="Opticks by Newton"
    ["14725"]="Dialogue Concerning Two New Sciences by Galileo"
    ["5001"]="Experiments with Alternate Currents by Tesla"
    ["15491"]="The Principles of Chemistry by Mendeleev"
)

declare -A MATHEMATICS_BOOKS=(
    ["21076"]="The Elements of Euclid"
    ["13700"]="An Introduction to Mathematics by Whitehead"
    ["33283"]="A Treatise on Probability by Keynes"
    ["28820"]="Calculus Made Easy by Thompson"
)

declare -A SURVIVAL_BOOKS=(
    ["28800"]="Manual of Gardening by Bailey"
    ["32154"]="Woodcraft by Nessmuk"
    ["39129"]="Foods and Household Management by Kinne"
    ["40514"]="Handbook of Nature Study by Comstock"
)

download_offline_content() {
    log_message "Setting up offline content library..."
    
    # Create content directories if they don't exist
    mkdir -p "${STORAGE_ROOT}/library"/{Philosophy,Science,History,Survival,Mathematics,Literature,Wikipedia,Reference}
    
    # Download Wikipedia dump
    log_message "Downloading Wikipedia dump..."
    wget -c "https://dumps.wikimedia.org/enwiki/latest/enwiki-latest-pages-articles.xml.bz2" \
        -O "${STORAGE_ROOT}/library/Wikipedia/wiki_dump.xml.bz2"
    
    # Download Project Gutenberg books
    log_message "Downloading Project Gutenberg books..."
    download_all_books
    
    # Download survival manuals
    log_message "Downloading survival manuals..."
    download_survival_manuals
    
    log_message "${GREEN}Content download complete${NC}"
}

download_gutenberg_books() {
    local category=$1
    local -n books=$2  # Reference to the array
    local output_dir="${STORAGE_ROOT}/library/${category}"
    
    mkdir -p "$output_dir"
    log_message "Downloading ${category} books..."
    
    for book_id in "${!books[@]}"; do
        local title="${books[$book_id]}"
        local base_name=$(echo "$title" | cut -d' ' -f1-3 | tr ' ' '_')
        local output_file="${output_dir}/${base_name}.txt"
        
        log_message "Downloading: ${title} (ID: ${book_id})"
        
        # Try different URL formats
        local urls=(
            "https://www.gutenberg.org/cache/epub/${book_id}/pg${book_id}.txt"
            "https://www.gutenberg.org/files/${book_id}/${book_id}.txt"
            "https://www.gutenberg.org/files/${book_id}/${book_id}-0.txt"
            "https://www.gutenberg.org/ebooks/${book_id}.txt.utf-8"
        )
        
        local success=0
        for url in "${urls[@]}"; do
            if wget --timeout=30 --tries=3 -q -O "$output_file" "$url"; then
                if [ -s "$output_file" ]; then
                    log_message "${GREEN}Successfully downloaded: ${title}${NC}"
                    success=1
                    break
                fi
            fi
        done
        
        if [ $success -eq 0 ]; then
            log_message "${RED}Failed to download: ${title}${NC}"
        fi
        
        # Rate limiting to be nice to Gutenberg servers
        sleep 2
    done
}

download_all_books() {
    log_message "Starting comprehensive book download..."
    
    # Download books by category
    download_gutenberg_books "Philosophy" PHILOSOPHY_BOOKS
    download_gutenberg_books "Science" SCIENCE_BOOKS
    download_gutenberg_books "Mathematics" MATHEMATICS_BOOKS
    download_gutenberg_books "Survival" SURVIVAL_BOOKS
    
    # Verify downloads
    verify_downloads
    
    log_message "${GREEN}Book download complete!${NC}"
}

verify_downloads() {
    local total_files=0
    local empty_files=0
    
    log_message "Verifying downloads..."
    
    for category in Philosophy Science Mathematics Survival; do
        local dir="${STORAGE_ROOT}/library/${category}"
        if [ -d "$dir" ]; then
            local files=$(find "$dir" -type f -name "*.txt")
            total_files=$((total_files + $(echo "$files" | wc -l)))
            empty_files=$((empty_files + $(find "$dir" -type f -empty | wc -l)))
        fi
    done
    
    log_message "Download statistics:"
    log_message "Total files: ${total_files}"
    log_message "Successfully downloaded: $((total_files - empty_files))"
    log_message "Failed downloads: ${empty_files}"
}

download_survival_manuals() {
    local manuals=(
        "milmanual-fm-21-76-us-army-survival-manual"
        "doomsdaybookofmedicine"
        "bushcraft-101"
        "backtobasicscomplete"
        "rocketstovemanual"
    )
    
    for manual in "${manuals[@]}"; do
        wget -c "https://archive.org/download/${manual}/${manual}.pdf" \
            -O "${STORAGE_ROOT}/library/Survival/${manual}.pdf"
    done
}

# Run the download if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    download_offline_content
fi 