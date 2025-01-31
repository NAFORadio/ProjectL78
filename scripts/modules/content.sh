#!/bin/bash
# Content management module for offline library

source "$(dirname "$0")/../common/utils.sh"

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
    download_gutenberg_books
    
    # Download survival manuals
    log_message "Downloading survival manuals..."
    download_survival_manuals
    
    log_message "${GREEN}Content download complete${NC}"
}

download_gutenberg_books() {
    local books=(
        "1497" # Plato - The Republic
        "8438" # Aristotle - Nicomachean Ethics
        "4280" # Kant - Critique of Pure Reason
        "1998" # Nietzsche - Thus Spoke Zarathustra
        "21076" # Euclid's Elements
        "28233" # Newton's Principia
        "1016" # Tesla - My Inventions
        "1228" # Darwin - Origin of Species
    )
    
    for book_id in "${books[@]}"; do
        wget -c "https://www.gutenberg.org/files/${book_id}/${book_id}.txt" \
            -O "${STORAGE_ROOT}/library/Literature/${book_id}.txt"
    done
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