#!/bin/bash

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
MAPPING_FILE="$HOME/Desktop/filename_mapping.csv"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to create a mapping file for renamed items
create_mapping() {
    echo "Original Name,Short Name,Location" > "$MAPPING_FILE"
    log_message "Created mapping file at: $MAPPING_FILE"
}

# Function to add to mapping file
add_to_mapping() {
    local original="$1"
    local shortened="$2"
    local location="$3"
    echo "\"$original\",\"$shortened\",\"$location\"" >> "$MAPPING_FILE"
}

# Function to create meaningful abbreviation
create_abbreviation() {
    local text="$1"
    local max_length="$2"
    
    # Split into words
    local words=($text)
    local abbrev=""
    
    # Handle different word counts differently
    if [ ${#words[@]} -le 2 ]; then
        # For 1-2 words, take more characters from each
        for word in "${words[@]}"; do
            abbrev+="${word:0:4}"
        done
    else
        # For 3+ words, take first letter of small words, more from key words
        local word_count=0
        for word in "${words[@]}"; do
            if [ ${#word} -le 3 ]; then
                # Short words get first letter
                abbrev+="${word:0:1}"
            else
                # Longer words get first 3 letters
                abbrev+="${word:0:3}"
            fi
            ((word_count++))
            if [ ${#abbrev} -ge $max_length ]; then
                break
            fi
        done
    fi
    
    # Ensure it's not too long
    echo "${abbrev:0:$max_length}"
}

# Function to shorten a filename
shorten_name() {
    local filename="$1"
    local extension="${filename##*.}"
    local basename="${filename%.*}"
    
    # Clean the name but preserve some punctuation
    local clean_name=$(echo "$basename" | sed 's/[^a-zA-Z0-9 _-]//g')
    
    # Create meaningful abbreviation (max 8 chars for 8.3 compatibility)
    local short_name=$(create_abbreviation "$clean_name" 8)
    
    # Convert to uppercase and remove spaces
    short_name=$(echo "$short_name" | tr '[:lower:]' '[:upper:]' | tr -d ' ')
    
    # Add extension if it exists
    if [ "$filename" != "$basename" ]; then
        extension=$(echo "$extension" | tr '[:lower:]' '[:upper:]')
        short_name="${short_name:0:8}.${extension:0:3}"
    else
        short_name="${short_name:0:8}"
    fi
    
    echo "$short_name"
}

# Function to process a directory
process_directory() {
    local dir="$1"
    local count=0
    
    # Process all files and directories
    find "$dir" -depth -name "*" | while read item; do
        # Skip if it's the mapping file
        if [[ "$item" == *"filename_mapping.csv"* ]]; then
            continue
        fi
        
        local dirname=$(dirname "$item")
        local basename=$(basename "$item")
        local new_name=$(shorten_name "$basename")
        
        # Add numeric suffix if name collision
        while [ -e "$dirname/$new_name" ] && [ "$dirname/$basename" != "$dirname/$new_name" ]; do
            count=$((count + 1))
            if [ ! -z "${new_name##*.}" ]; then
                new_name="${new_name%.*}$count.${new_name##*.}"
            else
                new_name="${new_name}$count"
            fi
        done
        
        # Rename if different
        if [ "$basename" != "$new_name" ]; then
            mv "$item" "$dirname/$new_name"
            add_to_mapping "$basename" "$new_name" "$dirname"
            log_message "Renamed: $basename -> $new_name"
        fi
    done
}

# Main execution
main() {
    echo -e "${YELLOW}NAFO File Name Shortener for macOS${NC}"
    echo -e "${YELLOW}This will rename files to be MS-DOS compatible${NC}"
    echo
    read -p "Enter the path to process (drag folder here): " target_path
    
    # Remove quotes and escape characters from drag-and-drop path
    target_path=$(echo "$target_path" | sed 's/^["'\'']//' | sed 's/["'\'']$//' | sed 's/\\//g')
    
    if [ ! -d "$target_path" ]; then
        echo -e "${RED}Invalid directory path${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}Will process: $target_path${NC}"
    read -p "Continue? (y/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Operation cancelled"
        exit 0
    fi
    
    create_mapping
    process_directory "$target_path"
    
    echo -e "${GREEN}Processing complete!${NC}"
    echo "A mapping of original to new filenames has been saved to: $MAPPING_FILE"
}

# Run main process
main 