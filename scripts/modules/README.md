# Primitive Technology Downloaders
Knowledge Acquisition Department
Version: 0.0.2-pre-alpha

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