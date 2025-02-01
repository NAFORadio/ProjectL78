#!/bin/bash

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
UTILS_DIR="$(dirname "$0")"
INDEX_FILE="$UTILS_DIR/utils_index.html"

# Create index file
create_utils_index() {
    cat > "$INDEX_FILE" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>NAFO Radio Utils Knowledge Base</title>
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
        h1, h2 {
            color: var(--matrix-green);
            text-shadow: 0 0 10px var(--matrix-green);
        }
        .stats {
            color: var(--matrix-green);
            font-size: 0.9em;
            margin-bottom: 20px;
        }
        .utils-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(400px, 1fr));
            gap: 20px;
            padding: 20px;
        }
        .util-card {
            background-color: var(--matrix-dark);
            border: 1px solid var(--matrix-green);
            border-radius: 5px;
            padding: 20px;
            transition: transform 0.2s, box-shadow 0.2s;
        }
        .util-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 0 15px var(--matrix-green);
        }
        .util-title {
            color: var(--matrix-green);
            font-weight: bold;
            margin-bottom: 10px;
            font-size: 1.2em;
        }
        .util-desc {
            font-size: 0.9em;
            margin-bottom: 15px;
        }
        .util-usage {
            background-color: rgba(0,255,65,0.1);
            padding: 10px;
            border-radius: 3px;
            font-family: monospace;
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
        <h1>NAFO Radio Utils Knowledge Base</h1>
        <div class="stats">
            System Utilities and Tools | Last Updated: $(date '+%Y-%m-%d %H:%M')
        </div>
    </div>
    <div class="utils-grid">
        <!-- Git Setup Utility -->
        <div class="util-card">
            <div class="util-title">Git Setup Utility</div>
            <div class="util-desc">
                Installs and configures Git for Raspberry Pi systems. Provides comprehensive
                setup instructions and best practices for version control.
            </div>
            <div class="util-usage">
                <strong>Usage:</strong><br>
                chmod +x git_setup.sh<br>
                sudo ./git_setup.sh
            </div>
            <div class="util-desc">
                <a href="docs/git_setup.html" style="color: var(--matrix-green);">Detailed Documentation →</a>
            </div>
        </div>

        <!-- Drive Mount Utility -->
        <div class="util-card">
            <div class="util-title">Drive Mount Utility</div>
            <div class="util-desc">
                Automates the process of mounting drives on Raspberry Pi systems with
                proper permissions and persistent configuration.
            </div>
            <div class="util-usage">
                <strong>Usage:</strong><br>
                chmod +x mount_drive.sh<br>
                sudo ./mount_drive.sh
            </div>
            <div class="util-desc">
                <a href="docs/mount_drive.html" style="color: var(--matrix-green);">Detailed Documentation →</a>
            </div>
        </div>

        <!-- Mac Filename Shortener -->
        <div class="util-card">
            <div class="util-title">macOS Filename Shortener</div>
            <div class="util-desc">
                Creates MS-DOS compatible filenames from macOS files.
            </div>
            <div class="util-usage">
                <strong>Usage:</strong><br>
                chmod +x mac_shorten_names.sh<br>
                ./mac_shorten_names.sh [directory]
            </div>
            <div class="util-desc">
                <a href="docs/mac_shorten_names.html" style="color: var(--matrix-green);">Detailed Documentation →</a>
            </div>
        </div>

        <!-- UPS Manual Scraper -->
        <div class="util-card">
            <div class="util-title">UPS Manual Archival Tool</div>
            <div class="util-desc">
                Downloads and archives UPS manual documentation for offline access.
            </div>
            <div class="util-usage">
                <strong>Usage:</strong><br>
                chmod +x scrape_ups_manual.sh<br>
                ./scrape_ups_manual.sh
            </div>
            <div class="util-desc">
                <a href="docs/scrape_ups_manual.html" style="color: var(--matrix-green);">Detailed Documentation →</a>
            </div>
        </div>

        <!-- Installation Script -->
        <div class="util-card">
            <div class="util-title">NAFO Radio Installer</div>
            <div class="util-desc">
                Master installation script for NAFO Radio environment setup.
            </div>
            <div class="util-usage">
                <strong>Usage:</strong><br>
                chmod +x install.sh<br>
                sudo ./install.sh
            </div>
            <div class="util-desc">
                <a href="docs/install.html" style="color: var(--matrix-green);">Detailed Documentation →</a>
            </div>
        </div>

        <!-- System Destroy -->
        <div class="util-card">
            <div class="util-title">Emergency System Cleanup</div>
            <div class="util-desc">
                Emergency utility for secure data removal. Use with extreme caution.
            </div>
            <div class="util-usage">
                <strong>Usage:</strong><br>
                chmod +x destroy_me.sh<br>
                sudo ./destroy_me.sh --confirm
            </div>
            <div class="util-desc">
                <a href="docs/destroy_me.html" style="color: var(--matrix-green);">Detailed Documentation →</a>
            </div>
        </div>
    </div>

    <div class="support">
        <h2>Support Development</h2>
        <p>ETH Wallet: 0x4AcD49Aca41E31aa54f43e3109e7b0dB47369B65</p>
        <p>Report issues: naforadio@gmail.com</p>
    </div>
</body>
</html>
EOF

    echo -e "${GREEN}Utils knowledge base created at: $INDEX_FILE${NC}"
}

# Main function
main() {
    echo -e "${YELLOW}Creating NAFO Radio Utils Knowledge Base...${NC}"
    create_utils_index
}

# Run main process
main 