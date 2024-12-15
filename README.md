# Media-Sort

## Table of Contents
- [Overview](#overview)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Enhancements (Optional)](#enhancements-optional)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)
- [Contribution](#contribution)
- [License](#license)

## Overview
`Media-Sort` is a Bash script designed to organize media files into a structured folder hierarchy based on their EXIF metadata or file creation date. The script sorts files into a `yyyy/mm/dd` folder structure and handles duplicate files by checking their MD5 checksums.

## Features
- Sorts files into `yyyy/mm/dd` folder structure based on EXIF metadata or file creation date.
- Moves files without EXIF data to an `unknown` directory.
- Handles duplicate files by checking MD5 checksums and renaming files if necessary.
- Uses `rsync` for efficient file operations.
- Supports parallel processing using GNU Parallel or xargs.
- Dry-run mode to simulate file moves without modifying the filesystem.
- Excludes hidden files from processing.
- Displays progress and speed of file processing.

## Requirements
- `bash`
- `exiftool`
- `rsync`
- `md5sum`
- `parallel` (optional, for parallel processing)
- `pv` (for displaying progress and speed)

## Installation
1. Install necessary dependencies:
   ```bash
   sudo apt-get install exiftool rsync md5sum parallel pv
   ```

## Usage

1. **Dry-Run Mode** (Preview changes):
   ```bash
   ./sort_files.sh --dry-run
   ```

2. **Actual Run**:
   ```bash
   ./sort_files.sh
   ```

---

## Parameters

- `SOURCE_DIR`: Path to the source directory containing files to sort.
- `DEST_DIR`: Path to the destination directory where sorted files will be saved.

The script includes hardcoded paths for these variables:
```bash
SOURCE_DIR="/media/amit/FP80/moveme/"
DEST_DIR="/media/amit/FP80/sort/"
```

Modify these paths as per your requirements or enhance the script to accept them as command-line arguments.

---

## Logs

- **Error Log**: `sort_images_error.log` is created in the destination directory to record any errors.
- **Progress Updates**: Displayed live on the terminal.

---

## Challenges Faced and Solutions

### 1. **EXIF Metadata Issues**
   - **Problem**: Some files lacked `DateTimeOriginal` or `CreateDate` metadata.
   - **Solution**: Added fallback to alternative metadata fields (`MediaCreateDate`, `ModifyDate`, `FileCreateDate`). If metadata was unavailable, the script defaulted to the file system's creation date.

### 2. **Duplicate File Handling**
   - **Problem**: Files with the same name but different content caused overwrites.
   - **Solution**: Implemented `md5sum` hashing to compare file content. Files with matching hashes were treated as duplicates and skipped.

### 3. **Handling Read-Only Files**
   - **Problem**: The script failed on read-only files.
   - **Solution**: Added a check to skip read-only files, logging their details in the error log.

### 4. **Progress Tracking**
   - **Problem**: No indication of script progress for large file sets.
   - **Solution**: Implemented a counter to display processed files vs. total files.

### 5. **Log File Overwrites**
   - **Problem**: The error log file (`sort_images_error.log`) was overwritten on subsequent runs.
   - **Solution**: Added a timestamped backup mechanism for existing log files.

### 6. **GNU Parallel Unavailability**
   - **Problem**: The script depended on `GNU Parallel`, which might not be installed on all systems.
   - **Solution**: Added a fallback to `xargs` for compatibility.

---

## Enhancements (Optional)

1. **Customizable Paths**:
   - Modify the script to accept `SOURCE_DIR` and `DEST_DIR` as command-line arguments.

2. **File Type Filtering**:
   - Add options to include/exclude specific file types (e.g., images, videos).

3. **Verbose Mode**:
   - Implement a `--verbose` flag for detailed logs.

4. **Parallel Processing Optimization**:
   - Allow users to specify the number of parallel jobs (`-j` option).

---

## Testing

- Test with diverse file types and metadata to ensure proper sorting.
- Use dry-run mode to verify changes without affecting original files.

---

## License

This script is provided "as-is" under the MIT License. Feel free to modify and distribute it as needed.
