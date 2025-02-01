#!/bin/bash

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Clear screen
clear

# Display NAFO Radio banner
cat << "EOF"
===============================================================
 _   _    _    _____ ___    ____          _ _       
| \ | |  / \  |  ___|_ _|  |  _ \ __ _ __| (_) ___  
|  \| | / _ \ | |_   | |   | |_) / _` / _` | |/ _ \ 
| |\  |/ ___ \|  _|  | |   |  _ < (_| (_| | | (_) |
|_| \_/_/   \_\_|   |___|  |_| \_\__,_\__,_|_|\___/ 
    
    Knowledge Acquisition Department
    Version Control Division
===============================================================

NAFO RADIO GIT SETUP UTILITY
---------------------------------------------------------------
This tool installs and configures Git for Raspberry Pi systems.
Department: Knowledge Acquisition
Division: Version Control
Classification: Educational/Setup
Version: 0.0.2-pre-alpha
---------------------------------------------------------------

LEGAL NOTICE AND DISCLAIMER
---------------------------------------------------------------
This tool is part of the NAFO Radio Knowledge Acquisition
system, designed for educational and setup purposes.

1. Usage Requirements:
   - Authorized NAFO Radio personnel only
   - Educational/Research purposes only
   - Must comply with all applicable laws and regulations

2. Classification:
   - Internal NAFO Radio tool
   - Not for public distribution
   - Handle in accordance with department guidelines
===============================================================
EOF

# Require explicit acceptance
read -p "NAFO Radio Personnel - Do you acknowledge and accept these terms? (yes/no): " accept
if [[ ! "$accept" =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${RED}Terms not accepted. Terminating session...${NC}"
    exit 1
fi

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}This script must be run as root. Try: sudo $0${NC}"
        exit 1
    fi
}

# Function to install Git
install_git() {
    echo -e "${YELLOW}Updating package lists...${NC}"
    apt-get update -qq
    
    echo -e "${YELLOW}Installing Git...${NC}"
    apt-get install -y git
    
    if ! command -v git &> /dev/null; then
        echo -e "${RED}Git installation failed${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Git installed successfully${NC}"
}

# Function to display Git instructions
show_instructions() {
    cat << "INSTRUCTIONS"

===============================================================
                    GIT SETUP INSTRUCTIONS
===============================================================

1. Initial Configuration
-----------------------
# Set your username
git config --global user.name "Your Name"

# Set your email
git config --global user.email "your.email@example.com"

2. Create New Repository
-----------------------
# Navigate to your project directory
cd /path/to/your/project

# Initialize repository
git init

# Add all files
git add .

# Initial commit
git commit -m "Initial commit"

3. Connect to Remote Repository
-----------------------------
# Add remote repository
git remote add origin your-repository-url

# Push to remote
git push -u origin main

4. Common Commands
----------------
# Check status
git status

# View changes
git diff

# Stage changes
git add filename
git add .  # all files

# Commit changes
git commit -m "Your commit message"

# Push changes
git push

# Pull updates
git pull

# View commit history
git log

5. Branch Management
------------------
# Create branch
git branch branch-name

# Switch branch
git checkout branch-name

# Create and switch
git checkout -b branch-name

# Merge branch
git merge branch-name

6. Best Practices
---------------
- Commit often
- Write clear commit messages
- Pull before pushing
- Create meaningful branches
- Review changes before committing

7. Troubleshooting
----------------
# Discard changes
git checkout -- filename

# Undo last commit
git reset --soft HEAD^

# Force pull
git fetch --all
git reset --hard origin/main

===============================================================
                    SUPPORT DEVELOPMENT
===============================================================
ETH Wallet: 0x4AcD49Aca41E31aa54f43e3109e7b0dB47369B65

For issues: naforadio@gmail.com
===============================================================

INSTRUCTIONS"
}

# Main function
main() {
    check_root
    install_git
    show_instructions
    
    echo -e "\n${GREEN}Git setup complete!${NC}"
    echo -e "${YELLOW}Instructions have been displayed above.${NC}"
    echo -e "${YELLOW}Consider saving these instructions for future reference.${NC}"
    
    # Offer to save instructions
    read -p "Would you like to save the instructions to a file? (yes/no): " save
    if [[ "$save" =~ ^[Yy][Ee][Ss]$ ]]; then
        show_instructions > git_instructions.md
        echo -e "${GREEN}Instructions saved to: $(pwd)/git_instructions.md${NC}"
    fi
}

# Run main process
main 