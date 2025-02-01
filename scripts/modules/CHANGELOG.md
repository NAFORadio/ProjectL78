# NAFO Radio Modules Changelog 🇺🇦

## gutenberg_download.sh
### [2024-03-XX]
- Updated macOS storage path to /Data/Storage/Books
- Added directory creation with proper permissions
- Switched to open-source EPUB viewers for macOS
- Added Sigil and CoolReader as alternatives
- Added create_storage_dirs function
- Previous changes:
  - Added macOS support
  - Added Homebrew installation check
  - Modified storage location for macOS
  - Added macOS-specific EPUB viewers
  - Added OS-specific permission handling
  - Added OS detection and configuration
  - Initial creation
  - Added book downloading functionality
  - Added EPUB viewer installation
  - Added multi-format support (TXT + EPUB)
  - Added metadata generation
  - Added HTML index creation
  - [FIXED] File naming to include author
  - [FIXED] Storage location to /mnt/data/Books
  - [FIXED] Permission handling
  - Added download verification
  - Improved error handling 