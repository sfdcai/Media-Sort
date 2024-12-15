#!/bin/bash

# Script to sort files into yyyy/mm/dd folder structure based on EXIF or file creation date

set -o errexit
set -o pipefail

# Hardcoded source and destination directories
SOURCE_DIR="/media/amit/FP80/moveme/"          # Replace with actual source directory
DEST_DIR="/media/amit/FP80/sort/"  # Hardcoded destination directory

# Dry-run mode
DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
fi

# Verify source directory exists
if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "Error: Source directory '$SOURCE_DIR' does not exist."
    exit 1
fi

# Verify destination directory exists and is writable
if [[ ! -d "$DEST_DIR" || ! -w "$DEST_DIR" ]]; then
    echo "Error: Destination directory '$DEST_DIR' does not exist or is not writable."
    exit 1
fi

# Create destination directory if it does not exist
mkdir -p "$DEST_DIR"

LOG_FILE="${DEST_DIR}/sort_images_error.log"
if [[ -f "$LOG_FILE" ]]; then
    mv "$LOG_FILE" "${LOG_FILE}_$(date +"%Y%m%d%H%M%S")"
fi
> "$LOG_FILE"

TOTAL_PROCESSED=0
TOTAL_SKIPPED=0

# Count total files for progress monitoring
TOTAL_FILES=$(find "$SOURCE_DIR" -type f ! -type l ! -name ".*" | wc -l)
PROCESSED=0

# Function to process each file
process_file() {
    local FILE="$1"
    local DATE

    # Skip read-only files
    if [[ ! -w "$FILE" ]]; then
        echo "$(date +"%Y-%m-%d %H:%M:%S") - Skipping read-only file: $FILE" | tee -a "$LOG_FILE"
        return 0
    fi

    # Try to get the date from EXIF metadata (photos and videos)
    DATE=$(exiftool -DateTimeOriginal -d "%Y-%m-%d" "$FILE" | awk -F': ' '{print $2}' | tr -d '[:space:]')

    # If EXIF date is not available, check QuickTime metadata for videos
    if [[ -z "$DATE" ]]; then
        DATE=$(exiftool -CreateDate -d "%Y-%m-%d" "$FILE" | awk -F': ' '{print $2}' | tr -d '[:space:]')
    fi

    # Additional metadata tags for better accuracy
    if [[ -z "$DATE" ]]; then
        DATE=$(exiftool -MediaCreateDate -d "%Y-%m-%d" "$FILE" | awk -F': ' '{print $2}' | tr -d '[:space:]')
    fi
    if [[ -z "$DATE" ]]; then
        DATE=$(exiftool -ModifyDate -d "%Y-%m-%d" "$FILE" | awk -F': ' '{print $2}' | tr -d '[:space:]')
    fi
    if [[ -z "$DATE" ]]; then
        DATE=$(exiftool -FileCreateDate -d "%Y-%m-%d" "$FILE" | awk -F': ' '{print $2}' | tr -d '[:space:]')
    fi

    # If metadata is still unavailable, use file creation date
    if [[ -z "$DATE" ]]; then
        DATE=$(date -r "$FILE" +"%Y-%m-%d" 2>/dev/null) || DATE=""
    fi

    if [[ -z "$DATE" ]]; then
        local TARGET_DIR="$DEST_DIR/unknown"
    else
        local YEAR=$(echo "$DATE" | cut -d'-' -f1)
        local MONTH=$(echo "$DATE" | cut -d'-' -f2)
        local DAY=$(echo "$DATE" | cut -d'-' -f3)
        local TARGET_DIR="$DEST_DIR/$YEAR/$MONTH/$DAY"
    fi

    # Create target directory if it doesn't exist
    if ! mkdir -p "$TARGET_DIR"; then
        echo "$(date +"%Y-%m-%d %H:%M:%S") - Failed to create directory: $TARGET_DIR" | tee -a "$LOG_FILE"
        return 1
    fi

    # Determine the new filename if a file with the same name already exists
    local BASENAME=$(basename "$FILE")
    local NEWFILE="$TARGET_DIR/$BASENAME"
    local COUNT=1
    local FILE_HASH=$(md5sum "$FILE" | awk '{print $1}')

    while [[ -e "$NEWFILE" ]]; do
        local EXISTING_HASH=$(md5sum "$NEWFILE" | awk '{print $1}')
        if [[ "$FILE_HASH" == "$EXISTING_HASH" ]]; then
            echo "$(date +"%Y-%m-%d %H:%M:%S") - Skipping duplicate file: $FILE"
            TOTAL_SKIPPED=$((TOTAL_SKIPPED + 1))
            return 0
        fi
        if [[ $COUNT -gt 1000 ]]; then
            echo "$(date +"%Y-%m-%d %H:%M:%S") - Too many duplicates for $FILE. Skipping." | tee -a "$LOG_FILE"
            return 1
        fi
        NEWFILE="$TARGET_DIR/${BASENAME%.*}_$COUNT.${BASENAME##*.}"
        COUNT=$((COUNT + 1))
    done

    if $DRY_RUN; then
        echo "$(date +"%Y-%m-%d %H:%M:%S") - Would move $FILE to $NEWFILE"
        return 0
    fi

    # Move file to target directory using rsync with --remove-source-files
    if rsync -a --remove-source-files --no-perms --no-owner --no-group "$FILE" "$NEWFILE"; then
        echo "$(date +"%Y-%m-%d %H:%M:%S") - Moved to: $NEWFILE"
        TOTAL_PROCESSED=$((TOTAL_PROCESSED + 1))
    else
        echo "$(date +"%Y-%m-%d %H:%M:%S") - Failed to move: $FILE" | tee -a "$LOG_FILE"
        return 1
    fi

    PROCESSED=$((PROCESSED + 1))
    echo -ne "Progress: $PROCESSED/$TOTAL_FILES\r"
}

# Export the function for parallel processing
export -f process_file
export DEST_DIR

# Check for empty source directory
if [[ -z $(find "$SOURCE_DIR" -type f ! -type l ! -name ".*") ]]; then
    echo "No files found in source directory '$SOURCE_DIR'."
    exit 0
fi

# Use GNU Parallel or fallback to xargs
if command -v parallel > /dev/null 2>&1; then
    echo "$(date +"%Y-%m-%d %H:%M:%S") - Using GNU Parallel for processing."
    find "$SOURCE_DIR" -type f ! -type l ! -name ".*" -print0 | parallel -0 -j "$(nproc)" process_file
else
    echo "$(date +"%Y-%m-%d %H:%M:%S") - GNU Parallel not found. Using fallback (xargs)."
    find "$SOURCE_DIR" -type f ! -type l ! -name ".*" -print0 | xargs -0 -I {} bash -c 'process_file "$@"' _ {}
fi

# Remove empty directories
find "$SOURCE_DIR" -depth -type d -empty -delete

# Summary report
echo "=== Summary ==="
echo "Files processed: $TOTAL_PROCESSED"
echo "Duplicates skipped: $TOTAL_SKIPPED"
echo "Errors logged: $(grep -c 'Failed' "$LOG_FILE")"

echo "$(date +"%Y-%m-%d %H:%M:%S") - Sorting completed. Check '$LOG_FILE' for any errors."