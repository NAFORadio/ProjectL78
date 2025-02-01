# NAFO Radio Modules Changelog 🇺🇦

## gutenberg_download.sh
### [2024-03-XX]
- [FIXED] macOS storage path to use $HOME/Library/NAFO/Books
- [FIXED] Permission and directory creation issues on macOS
- [FIXED] Read-only filesystem errors
- Removed need for sudo on macOS
- Previous changes:
  - Added cross-platform support
  - Updated storage paths
  - Added directory creation with proper permissions
  - Switched to open-source EPUB viewers
  - Added create_storage_dirs function
  - Added OS detection and configuration
  - Added multi-format support (TXT + EPUB)
  - Added metadata generation
  - Added HTML index creation
  - [FIXED] File naming to include author
  - [FIXED] Permission handling
  - Added download verification
  - Improved error handling

## raid.sh
### [2024-03-XX]
- Initial creation
- Added RAID configuration support
- Added array management
- Added status monitoring

## security.sh
### [2024-03-XX]
- Initial creation
- Added system hardening
- Added password policies
- Added security monitoring

## software.sh
### [2024-03-XX]
- Initial creation
- Added package management
- Added dependency handling
- Added clean installation support

## General Updates
### [2024-03-XX]
- Added cross-platform support where applicable
- Improved error handling across modules
- Added NAFO-style documentation
- Enhanced user feedback
- Added changelogs
- Improved module organization 