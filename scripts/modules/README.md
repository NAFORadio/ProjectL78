# 🐕 NAFO Radio Modules 🇺🇦

## About These Bad Boys
Welcome to the NAFO Radio modules collection, where we keep our specialized tools that hit harder than Russian cope cages. Each module is designed to be as reliable as Ukrainian artillery and more effective than Russian logistics.

## Available Modules

### 📚 Gutenberg Library Downloader
- Downloads books faster than Russian tanks abandon their positions
- Grabs both TXT and EPUB formats (double tap!)
- Organizes books better than Russian military hierarchy
- Creates proper metadata (unlike Russian casualty reports)
- Includes EPUB viewer installation (better UI than Russian targeting systems)

Usage:

## Overview
These scripts archive educational content from the Primitive Technology channel for offline preservation and study.

## Components

### 1. Linux/macOS Version (primitive_tech_downloader.sh)
### 2. Windows Version (primitive_tech_downloader.bat)

## Features

### Video Download
- Downloads videos from Primitive Technology channel
- Supports multiple quality levels (720p default, 480p fallback)
- Handles connection interruptions
- Resumes partial downloads
- Verifies download integrity
- Organizes videos in clean directory structure

### Thumbnail Generation
- Creates thumbnails for each video
- Uses intelligent frame selection (2 seconds in)
- Generates 640px width previews
- Maintains aspect ratio
- Handles missing thumbnails gracefully
- Includes fallback placeholder image

### Index Creation
- Generates matrix-themed HTML index
- Shows video thumbnails
- Includes video descriptions
- Displays total video count
- Shows last update timestamp
- Supports direct video playback
- Mobile-friendly layout

### File Organization 

## Detailed Menu Options

### Option 1: Download videos and create index
When you select this option, the script will:
1. Check for required software
   - Python3
   - yt-dlp
   - ffmpeg
   - wget
2. Create directory structure
   - /Share Files/Primitive_Technology/
   - /Videos/
   - /logs/
3. Download each video
   - Attempts 720p quality first
   - Falls back to 480p if needed
   - Creates .description files
4. Generate thumbnails
   - 640px width previews
   - 16:9 aspect ratio
   - 2-second mark of video
5. Create video index
   - Matrix-themed HTML
   - Clickable thumbnails
   - Video descriptions
   - Last updated timestamp
Expected outcome: Complete video archive with index

### Option 2: Create/update index only
Use this when:
- Videos already downloaded
- Thumbnails missing
- Index corrupted
- Adding new videos

The script will:
1. Scan /Videos/ directory
2. Generate missing thumbnails
3. Extract video descriptions
4. Create new index.html
5. Verify all entries
Expected outcome: Fresh index.html with all videos listed

### Option 3: Generate/update thumbnails only
Use this to:
- Fix missing thumbnails
- Regenerate corrupted images
- Update thumbnail style
- Force thumbnail refresh

The script will:
1. Scan all .mp4 files
2. Check for matching .jpg
3. Generate missing thumbnails
4. Verify thumbnail integrity
5. Report results
Expected outcome: Complete set of thumbnails for all videos

### Option 4: Verify and fix video index
This option performs a full system check:
1. Directory structure verification
   - Checks all required folders
   - Creates missing directories
2. Video integrity check
   - Verifies each .mp4 file
   - Reports corrupted videos
3. Thumbnail verification
   - Checks all thumbnails exist
   - Regenerates if needed
4. Description file check
   - Verifies .description files
   - Reports missing descriptions
5. Index verification
   - Checks index.html exists
   - Verifies all videos listed
   - Updates if needed
Expected outcome: Verified and fixed archive

### Option q: Quit
Safely exits the script:
1. Completes current operations
2. Saves any pending changes
3. Closes log files
4. Reports final status
Expected outcome: Clean program exit

## Common Option Combinations

### First Time Setup
1. Run Option 1
2. Wait for completion
3. Run Option 4 to verify

### Monthly Maintenance
1. Run Option 1 (gets new videos)
2. Run Option 3 (fixes thumbnails)
3. Run Option 4 (verifies everything)

### Fixing Issues
If videos don't play:
1. Run Option 4 (verify files)
2. Run Option 1 (re-download corrupted)

If thumbnails missing:
1. Run Option 3 (regenerate thumbnails)
2. Run Option 2 (rebuild index)

If index broken:
1. Run Option 4 (verify all)
2. Run Option 2 (rebuild index)

## Option Outcomes Matrix

| Option | Time Required | Internet Needed | Disk Space Used | Common Issues |
|--------|---------------|-----------------|-----------------|---------------|
| 1      | 1-3 hours    | Yes            | ~200MB/video    | Connection timeouts |
| 2      | 1-5 minutes  | No             | ~100KB          | Permission errors |
| 3      | 5-15 minutes | No             | ~50KB/thumbnail | FFmpeg errors |
| 4      | 5-10 minutes | No             | None            | None typical |

## Running the Script

### First Time Setup

1. Download the script:
   ```bash
   git clone [repository-url]
   cd nafo-radio/scripts/modules
   ```

2. Make the script executable:
   ```bash
   # Linux/macOS
   chmod +x primitive_tech_downloader.sh
   
   # Windows
   # No action needed
   ```

3. Install prerequisites:
   - The script will attempt to install required packages
   - You may need to provide sudo/admin password
   - Follow any prompts for package installation

### Running the Script

#### Linux/macOS
```bash
./primitive_tech_downloader.sh
``` 

## Support Development
Help maintain and improve these tools:

ETH Wallet: `0x4AcD49Aca41E31aa54f43e3109e7b0dB47369B65`

Your support ensures continued development and maintenance of these knowledge preservation tools. 