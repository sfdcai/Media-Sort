#!/bin/bash

# Script to sort files into yyyy/mm/dd folder structure based on EXIF or file creation date

set -o errexit
set -o pipefail

# Hardcoded source and destination directories
SOURCE_DIR="/media/amit/FP80/moveme/"          # Replace with actual source directory
DEST_DIR="/media/amit/FP80/sort/"  # Hardcoded destination directory

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

LOG_FILE="sort_images_error.log"
> "$LOG_FILE"

# Function to process each file
process_file() {
    local FILE="$1"
    local DATE

    # Try to get the date from EXIF metadata
    DATE=$(exiftool -DateTimeOriginal -d "%Y-%m-%d" "$FILE" | awk -F': ' '{print $2}' | tr -d '[:space:]')
    
    # If EXIF date is not available, use the file creation date
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

    while [[ -e "$NEWFILE" ]]; do
        # Check if the existing file has the same MD5 checksum
        if [[ $(md5sum "$FILE" | awk '{print $1}') == $(md5sum "$NEWFILE" | awk '{print $1}') ]]; then
            echo "$(date +"%Y-%m-%d %H:%M:%S") - Skipping duplicate file: $FILE"
            return 0
        fi
        NEWFILE="$TARGET_DIR/${BASENAME%.*}_$COUNT.${BASENAME##*.}"
        COUNT=$((COUNT + 1))
    done

    # Move file to target directory using rsync with --remove-source-files
    if rsync -a --remove-source-files "$FILE" "$NEWFILE"; then
        echo "$(date +"%Y-%m-%d %H:%M:%S") - Moved to: $NEWFILE"
    else
        echo "$(date +"%Y-%m-%d %H:%M:%S") - Failed to move: $FILE" | tee -a "$LOG_FILE"
        return 1
    fi
}

# Export the function for parallel processing
export -f process_file
export DEST_DIR

# Use GNU Parallel or fallback to xargs
if command -v parallel > /dev/null 2>&1; then
    echo "$(date +"%Y-%m-%d %H:%M:%S") - Using GNU Parallel for processing."
    find "$SOURCE_DIR" -type f -print0 | parallel -0 -j "$(nproc)" process_file
else
    echo "$(date +"%Y-%m-%d %H:%M:%S") - GNU Parallel not found. Using fallback (xargs)."
    find "$SOURCE_DIR" -type f -print0 | xargs -0 -I {} bash -c 'process_file "$@"' _ {}
fi

echo "$(date +"%Y-%m-%d %H:%M:%S") - Sorting completed. Check '$LOG_FILE' for any errors."