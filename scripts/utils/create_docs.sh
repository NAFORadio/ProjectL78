#!/bin/bash

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
UTILS_DIR="$(dirname "$0")"
DOCS_DIR="$UTILS_DIR/docs"

# Create docs directory
mkdir -p "$DOCS_DIR"

# Function to create documentation for each utility
create_utility_doc() {
    local util_name="$1"
    local util_title="$2"
    local util_desc="$3"
    local util_usage="$4"
    local util_features="$5"
    local util_troubleshooting="$6"

    cat > "$DOCS_DIR/${util_name}.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>NAFO Radio Utils - $util_title</title>
    <style>
        :root {
            --matrix-green: #00ff41;
            --matrix-dark: #0a0a0a;
            --matrix-darker: #050505;
            --text-color: #cccccc;
        }
        body {
            font-family: 'Courier New', monospace;
            background-color: var(--matrix-darker);
            color: var(--text-color);
            margin: 0;
            padding: 20px;
            line-height: 1.6;
        }
        .header {
            text-align: center;
            padding: 20px;
            border-bottom: 1px solid var(--matrix-green);
            margin-bottom: 30px;
        }
        h1, h2, h3 {
            color: var(--matrix-green);
            text-shadow: 0 0 10px var(--matrix-green);
        }
        .content {
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
        }
        .section {
            background-color: var(--matrix-dark);
            border: 1px solid var(--matrix-green);
            border-radius: 5px;
            padding: 20px;
            margin-bottom: 20px;
        }
        .code {
            background-color: rgba(0,255,65,0.1);
            padding: 10px;
            border-radius: 3px;
            font-family: monospace;
            white-space: pre-wrap;
        }
        .warning {
            color: #ff6b6b;
            border-left: 3px solid #ff6b6b;
            padding-left: 10px;
            margin: 10px 0;
        }
        .tip {
            color: var(--matrix-green);
            border-left: 3px solid var(--matrix-green);
            padding-left: 10px;
            margin: 10px 0;
        }
        .support {
            text-align: center;
            padding: 20px;
            margin-top: 30px;
            border-top: 1px solid var(--matrix-green);
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>$util_title</h1>
        <div class="stats">
            NAFO Radio Utils Documentation | Last Updated: $(date '+%Y-%m-%d %H:%M')
        </div>
    </div>

    <div class="content">
        <div class="section">
            <h2>Description</h2>
            $util_desc
        </div>

        <div class="section">
            <h2>Usage</h2>
            <div class="code">$util_usage</div>
        </div>

        <div class="section">
            <h2>Features</h2>
            $util_features
        </div>

        <div class="section">
            <h2>Troubleshooting</h2>
            $util_troubleshooting
        </div>

        <div class="support">
            <h2>Support Development</h2>
            <p>ETH Wallet: 0x4AcD49Aca41E31aa54f43e3109e7b0dB47369B65</p>
            <p>Report issues: naforadio@gmail.com</p>
        </div>
    </div>
</body>
</html>
EOF
}

# Create documentation for each utility
echo -e "${YELLOW}Creating utility documentation...${NC}"

# Mount Drive documentation
create_utility_doc "mount_drive" "Drive Mount Utility" \
"<p>Automates the process of mounting drives on Raspberry Pi systems with proper permissions and persistent configuration.</p>" \
"# Make script executable
chmod +x mount_drive.sh

# Run with sudo
sudo ./mount_drive.sh

# Follow the interactive prompts to:
1. Select drive to mount
2. Confirm mounting point
3. Set permissions" \
"<ul>
    <li>Interactive drive selection interface</li>
    <li>Automatic filesystem detection (ext4, NTFS, exFAT)</li>
    <li>Persistent mount configuration in /etc/fstab</li>
    <li>Proper permission management</li>
    <li>Automatic PARTUUID detection</li>
    <li>Backup of existing configurations</li>
</ul>" \
"<h3>Common Issues</h3>
<div class='warning'>Permission Denied</div>
<p>Solution: Ensure you're running with sudo</p>

<div class='warning'>Drive Not Detected</div>
<p>Solution: Check drive connection and run 'lsblk' to verify visibility</p>

<div class='warning'>Mount Failed</div>
<p>Solutions:
    <ul>
        <li>Check filesystem type</li>
        <li>Verify drive isn't already mounted</li>
        <li>Check for filesystem errors</li>
    </ul>
</p>"

# Git Setup documentation with enhanced GitHub instructions
create_utility_doc "git_setup" "Git Setup Utility" \
"<p>Comprehensive Git installation and configuration tool for Raspberry Pi systems. Includes detailed setup instructions and best practices for GitHub integration.</p>" \
"# Make script executable
chmod +x git_setup.sh

# Run with sudo
sudo ./git_setup.sh

# Initial setup:
git config --global user.name \"Your Name\"
git config --global user.email \"your.email@example.com\"

# Generate SSH key for GitHub:
ssh-keygen -t ed25519 -C \"your.email@example.com\"
cat ~/.ssh/id_ed25519.pub
# Add this key to GitHub in Settings -> SSH Keys" \
"<ul>
    <li>Automated Git installation</li>
    <li>User configuration guidance</li>
    <li>SSH key generation</li>
    <li>GitHub integration</li>
    <li>Command reference guide</li>
    <li>Best practices documentation</li>
    <li>Repository setup instructions</li>
    <li>Branch management guide</li>
</ul>

<h3>GitHub Workflow Guide</h3>

<h4>Clone Repository</h4>
<div class='code'>
# HTTPS method:
git clone https://github.com/username/repository.git

# SSH method (recommended):
git clone git@github.com:username/repository.git
</div>

<h4>Daily Workflow</h4>
<div class='code'>
# Get latest changes
git pull origin main

# Check status
git status

# Add changes
git add .

# Commit changes
git commit -m \"Descriptive message\"

# Push to GitHub
git push origin main
</div>

<h4>Branch Management</h4>
<div class='code'>
# Create new branch
git checkout -b feature-name

# Switch branches
git checkout main

# Push new branch
git push -u origin feature-name

# Merge branches
git checkout main
git merge feature-name
</div>

<h4>Fix Common Issues</h4>
<div class='code'>
# Fix merge conflicts
git status  # Check files with conflicts
# Edit files to resolve conflicts
git add .
git commit -m \"Resolved merge conflicts\"

# Undo last commit
git reset --soft HEAD^

# Undo changes in file
git checkout -- filename

# Force pull (caution!)
git fetch --all
git reset --hard origin/main
</div>

<h4>Advanced GitHub Features</h4>
<div class='code'>
# Create pull request (on GitHub):
1. Push your branch
2. Go to repository on GitHub
3. Click 'Pull requests'
4. Click 'New pull request'
5. Select your branch
6. Add description
7. Create pull request

# Sync fork with original:
git remote add upstream https://github.com/original/repository.git
git fetch upstream
git checkout main
git merge upstream/main
</div>" \
"<h3>Common Issues</h3>

<div class='warning'>Authentication Failed</div>
<p>Solutions:
    <ul>
        <li>Verify GitHub credentials</li>
        <li>Check SSH key is added to GitHub</li>
        <li>Ensure SSH agent is running: ssh-add ~/.ssh/id_ed25519</li>
    </ul>
</p>

<div class='warning'>Push Rejected</div>
<p>Solutions:
    <ul>
        <li>Pull latest changes first: git pull origin main</li>
        <li>Resolve any merge conflicts</li>
        <li>Force push if needed (careful!): git push -f origin main</li>
    </ul>
</p>

<div class='warning'>Merge Conflicts</div>
<p>Solutions:
    <ul>
        <li>Pull latest changes</li>
        <li>Open conflicted files and resolve markers</li>
        <li>Stage and commit resolved files</li>
        <li>Push changes</li>
    </ul>
</p>

<div class='tip'>Best Practices</div>
<p>
    <ul>
        <li>Always pull before starting work</li>
        <li>Create feature branches for new work</li>
        <li>Write clear commit messages</li>
        <li>Review changes before committing</li>
        <li>Keep commits small and focused</li>
        <li>Push regularly to avoid large conflicts</li>
    </ul>
</p>

<div class='tip'>SSH Key Setup</div>
<p>
    <ol>
        <li>Generate key: ssh-keygen -t ed25519</li>
        <li>Start agent: eval \"$(ssh-agent -s)\"</li>
        <li>Add key: ssh-add ~/.ssh/id_ed25519</li>
        <li>Copy key: cat ~/.ssh/id_ed25519.pub</li>
        <li>Add to GitHub: Settings -> SSH Keys</li>
        <li>Test: ssh -T git@github.com</li>
    </ol>
</p>"

# Mac Shorten Names documentation
create_utility_doc "mac_shorten_names" "macOS Filename Shortener" \
"<p>Utility for creating MS-DOS compatible filenames from macOS files. Essential for cross-platform compatibility and legacy systems.</p>" \
"# Make script executable
chmod +x mac_shorten_names.sh

# Run the script
./mac_shorten_names.sh [directory]

# Options:
-r : Recursive mode
-d : Dry run (preview changes)
-h : Show help" \
"<ul>
    <li>Automatic filename shortening</li>
    <li>MS-DOS compatibility check</li>
    <li>Recursive directory processing</li>
    <li>Preview mode</li>
    <li>Detailed logging</li>
    <li>Original filename backup</li>
</ul>" \
"<h3>Common Issues</h3>
<div class='warning'>Permission Errors</div>
<p>Solution: Check file and directory permissions</p>

<div class='warning'>Filename Conflicts</div>
<p>Solution: Use -d flag to preview changes first</p>

<div class='warning'>Special Characters</div>
<p>Solution: Enable UTF-8 support in target system</p>"

# UPS Manual Scraper documentation
create_utility_doc "scrape_ups_manual" "UPS Manual Archival Tool" \
"<p>Automated tool for downloading and archiving UPS manual documentation. Essential for maintaining offline access to critical documentation.</p>" \
"# Make script executable
chmod +x scrape_ups_manual.sh

# Run the script
./scrape_ups_manual.sh

# Optional flags:
--model [model number]
--all
--update" \
"<ul>
    <li>Automated manual detection</li>
    <li>PDF format conversion</li>
    <li>Metadata preservation</li>
    <li>Incremental updates</li>
    <li>Search functionality</li>
    <li>Offline access</li>
</ul>" \
"<h3>Common Issues</h3>
<div class='warning'>Download Failed</div>
<p>Solution: Check internet connection and retry</p>

<div class='warning'>PDF Conversion Error</div>
<p>Solution: Verify dependencies (wget, pdf-tools)</p>

<div class='warning'>Storage Space</div>
<p>Solution: Use --model flag for specific manuals only</p>"

# Install Script documentation
create_utility_doc "install" "NAFO Radio Installation Script" \
"<p>Master installation script for setting up the NAFO Radio environment and all its components.</p>" \
"# Make script executable
chmod +x install.sh

# Run with sudo
sudo ./install.sh

# Options:
--minimal : Basic installation
--full : Complete installation
--update : Update existing installation" \
"<ul>
    <li>Environment setup</li>
    <li>Dependency management</li>
    <li>Configuration validation</li>
    <li>Component installation</li>
    <li>Permission setup</li>
    <li>Update management</li>
</ul>" \
"<h3>Common Issues</h3>
<div class='warning'>Dependency Conflicts</div>
<p>Solution: Run with --clean flag first</p>

<div class='warning'>Permission Issues</div>
<p>Solution: Verify sudo access and user groups</p>

<div class='warning'>Space Requirements</div>
<p>Solution: Use --minimal for basic installation</p>"

# System Destroy documentation
create_utility_doc "destroy_me" "Emergency System Cleanup" \
"<p>Emergency utility for secure data removal and system cleanup. Use with extreme caution.</p>" \
"# Make script executable
chmod +x destroy_me.sh

# Run with explicit confirmation
sudo ./destroy_me.sh --confirm

# CRITICAL: This is irreversible" \
"<ul>
    <li>Secure data wiping</li>
    <li>Configuration removal</li>
    <li>Log cleanup</li>
    <li>System reset</li>
    <li>Multiple confirmation layers</li>
    <li>Audit logging</li>
</ul>" \
"<h3>Critical Warnings</h3>
<div class='warning'>IRREVERSIBLE OPERATION</div>
<p>This script permanently removes data</p>

<div class='warning'>Confirmation Required</div>
<p>Multiple confirmations needed to proceed</p>

<div class='warning'>System State</div>
<p>Ensure system is not in production use</p>"

echo -e "${GREEN}All utility documentation created successfully!${NC}" 