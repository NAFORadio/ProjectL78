#!/bin/bash

# Kiwix ZIM repository URL
BASE_URL="https://download.kiwix.org/zim/"

# Color codes - using more visible colors for dark terminals
GREEN='\033[0;32m'     # Success messages
YELLOW='\033[1;33m'    # Warnings and important info
RED='\033[1;31m'       # Errors
CYAN='\033[1;36m'      # Processing info
WHITE='\033[1;37m'     # Regular output
NC='\033[0m'           # No Color

echo -e "${CYAN}=== NAFO Radio ZIM Size Calculator ===${NC}"
echo -e "${YELLOW}Starting size calculation of English ZIM files...${NC}"
echo -e "Base URL: $BASE_URL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Function to convert size to MB with logging
to_mb() {
    local size=$1
    local value=$(echo "$size" | sed 's/[KMGT]$//')
    local unit=$(echo "$size" | grep -o '[KMGT]$')
    
    echo -e "${WHITE}Converting size: $size${NC}" >&2
    
    case $unit in
        K) 
            echo -e "${WHITE}Converting KB to MB: $value KB${NC}" >&2
            printf "%.0f" $(echo "scale=2; $value / 1024" | bc) ;;
        M) 
            echo -e "${WHITE}Size in MB: $value MB${NC}" >&2
            printf "%.0f" "$value" ;;
        G) 
            echo -e "${WHITE}Converting GB to MB: $value GB${NC}" >&2
            printf "%.0f" $(echo "scale=2; $value * 1024" | bc) ;;
        T) 
            echo -e "${WHITE}Converting TB to MB: $value TB${NC}" >&2
            printf "%.0f" $(echo "scale=2; $value * 1024 * 1024" | bc) ;;
        *) 
            echo -e "${RED}Unknown unit: $unit for size: $size${NC}" >&2
            echo "0" ;;
    esac
}

# Function to format size for display
format_size() {
    local mb=$1
    
    if [ -z "$mb" ] || [ "$mb" = "0" ]; then
        echo "0 MB"
        return
    fi
    
    echo -e "${CYAN}Formatting size: $mb MB${NC}" >&2
    
    if [ "$mb" -ge 1048576 ]; then  # 1024 * 1024
        printf "%.2f TB" $(echo "scale=2; $mb / 1024 / 1024" | bc)
    elif [ "$mb" -ge 1024 ]; then
        printf "%.2f GB" $(echo "scale=2; $mb / 1024" | bc)
    else
        printf "%.2f MB" $(echo "scale=2; $mb" | bc)
    fi
}

# Function to process a directory
process_directory() {
    local dir_url="$1"
    local dir_name="$2"
    local total_mb=0
    
    echo -e "\n${YELLOW}Processing directory: $dir_name${NC}"
    echo -e "${CYAN}Fetching directory listing from: $dir_url${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Get directory listing
    local listing=$(curl -s "$dir_url")
    
    if [[ -z "$listing" ]]; then
        echo -e "${RED}Error: Could not fetch directory listing${NC}"
        echo "0"
        return
    fi
    
    # Process files based on directory
    if [[ "$dir_name" == "wikipedia" ]]; then
        echo -e "${YELLOW}Wikipedia directory detected - looking for English maxi files only${NC}"
        while read -r line; do
            filename=$(echo "$line" | grep -Eo 'wikipedia_[^"]*\.zim')
            size=$(echo "$line" | grep -Eo '[0-9.]+[KMGT]' | tail -n1)
            
            if [ -n "$filename" ] && [ -n "$size" ]; then
                echo -e "${CYAN}Found file: $filename${NC}"
                mb=$(to_mb "$size")
                total_mb=$((total_mb + mb))
                formatted_size=$(format_size "$mb")
                printf "${GREEN}%-70s %15s${NC}\n" "$filename" "$formatted_size"
            fi
        done < <(echo "$listing" | grep -E 'href=".*_en_.*_maxi.*\.zim"')
    else
        echo -e "${YELLOW}Processing all English files in $dir_name${NC}"
        while read -r line; do
            filename=$(echo "$line" | grep -Eo '[^">]*_en_[^"]*\.zim')
            size=$(echo "$line" | grep -Eo '[0-9.]+[KMGT]' | tail -n1)
            
            if [ -n "$filename" ] && [ -n "$size" ]; then
                echo -e "${CYAN}Found file: $filename${NC}"
                mb=$(to_mb "$size")
                total_mb=$((total_mb + mb))
                formatted_size=$(format_size "$mb")
                printf "${GREEN}%-70s %15s${NC}\n" "$filename" "$formatted_size"
            fi
        done < <(echo "$listing" | grep -E 'href=".*_en_.*\.zim"')
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    formatted_total=$(format_size "$total_mb")
    echo -e "${GREEN}$dir_name Directory Total: $formatted_total${NC}"
    
    echo "$total_mb"
}

echo -e "${YELLOW}Fetching directory list from Kiwix...${NC}"

# Get list of directories
dirs=$(curl -s "$BASE_URL" | grep -Eo 'href="[^"]+/"' | sed -E 's/href="([^"]+)"/\1/' | grep -v '^/$\|^\.\./$')

if [[ -z "$dirs" ]]; then
    echo -e "${RED}Error: Could not fetch directory list${NC}"
    exit 1
fi

echo -e "${GREEN}Found $(echo "$dirs" | wc -l) directories to process${NC}"

# Process each directory and calculate grand total
grand_total=0
for dir in $dirs; do
    dir_name=${dir%/}
    echo -e "\n${YELLOW}Processing directory $dir_name...${NC}"
    dir_total=$(process_directory "${BASE_URL}${dir}" "$dir_name")
    grand_total=$(echo "$grand_total + $dir_total" | bc)
done

# Show grand total
echo -e "\n${YELLOW}=== Final Calculations ===${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
formatted_grand_total=$(format_size "$grand_total")
echo -e "${GREEN}Total Storage Required for All English ZIM Files: $formatted_grand_total${NC}"
echo -e "${CYAN}Calculation complete!${NC}" 