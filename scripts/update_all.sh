#!/bin/bash

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}NAFO Radio Project Update Utility${NC}"
echo -e "${YELLOW}Updating all documentation and utilities...${NC}"

# Update documentation
echo -e "${YELLOW}Updating documentation...${NC}"
./utils/create_docs.sh
./utils/create_utils_index.sh

# Update progress.txt
echo -e "${YELLOW}Updating progress tracking...${NC}"
cat > progress.txt << 'EOF'
NAFO Radio Project Progress
Version: 0.0.2-pre-alpha
Last Updated: $(date '+%Y-%m-%d %H:%M')

Completed Components:
✓ Primitive Technology Downloader
✓ Gutenberg Library Tool
✓ Drive Mount Utility
✓ Git Setup Utility
✓ Documentation System

In Progress:
- Knowledge Base Expansion
- Cross-platform Testing
- Error Handling Improvements
- User Interface Enhancements

Planned Features:
- Additional Utility Scripts
- Automated Testing
- Installation Verification
- Backup Systems

Known Issues:
- Pre-alpha status
- Some platform-specific bugs
- Documentation gaps
- Installation edge cases

Recent Updates:
- Added Git workflow documentation
- Enhanced mount drive interface
- Created documentation system
- Added utility knowledge base
- Improved error handling
EOF

# Automatically update README.md
echo -e "${YELLOW}Updating main README...${NC}"
cat > README.md << 'EOF'
# NAFO Radio Project

Build: $(date '+%Y-%m-%d') | Version: 0.0.2-pre-alpha
Knowledge Acquisition Department

⚠️ PRE-ALPHA SOFTWARE - USE AT YOUR OWN RISK ⚠️
This is highly experimental software in early development.

## Overview
NAFO Radio Project is a collection of scripts and tools for knowledge preservation and offline content management. This project focuses on maintaining critical information and content accessibility in austere environments.

## Components

### 1. Knowledge Acquisition Tools
- `primitive_tech_downloader.sh`: Primitive Technology video archival
- `gutenberg_download.sh`: Project Gutenberg library tool
- `scrape_ups_manual.sh`: UPS manual archival tool

### 2. System Utilities
- `mount_drive.sh`: Raspberry Pi drive mounting utility
- `git_setup.sh`: Git installation and configuration
- `mac_shorten_names.sh`: MS-DOS filename compatibility
- `destroy_me.sh`: Emergency system cleanup

### 3. Documentation
- Comprehensive knowledge base
- Matrix-themed interface
- Cross-referenced documentation
- Troubleshooting guides

## Installation
EOF

echo -e "${GREEN}Update complete!${NC}"
echo -e "Updated files:"
echo -e "- Documentation"
echo -e "- Utils index"
echo -e "- Progress tracking"
echo -e "- Main README"

echo -e "\n${YELLOW}Would you like to commit these changes to git? (yes/no):${NC}"
read -r commit_choice

if [[ "$commit_choice" =~ ^[Yy][Ee][Ss]$ ]]; then
    git add .
    git commit -m "Documentation update $(date '+%Y-%m-%d')"
    echo -e "${GREEN}Changes committed to git${NC}"
    echo -e "${YELLOW}Remember to push changes:${NC}"
    echo -e "git push origin main"
fi 