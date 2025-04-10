#!/bin/bash

# Get current username
USERNAME=$(whoami)
# Check for maximum number of arguments (extensions)
if [ "$#" -gt 4 ]; then
  echo "Error: Maximum of 4 file extensions are allowed as arguments."
  echo "Usage: w25backup.sh [extension1] [extension2] [extension3] [extension4]"
  exit 1 # Exit with an error code
fi
# Setup directories
BACKUP_ROOT="$HOME/backup"
FULL_BACKUP_DIR="$BACKUP_ROOT/fullbup"
INC_BACKUP_DIR="$BACKUP_ROOT/incbup"
DIFF_BACKUP_DIR="$BACKUP_ROOT/diffbup"
INCSIZE_BACKUP_DIR="$BACKUP_ROOT/incsizebup"
LOG_FILE="$HOME/w25log.txt"

# Timestamp files
TS_STEP1="$BACKUP_ROOT/.ts_step1"  # Timestamp for start of Step 1 (Full Backup)
TS_STEP2="$BACKUP_ROOT/.ts_step2"  # Timestamp for start of Step 2
TS_STEP3="$BACKUP_ROOT/.ts_step3"  # Timestamp for start of Step 3
TS_STEP4="$BACKUP_ROOT/.ts_step4"  # Timestamp for start of Step 4


# Create backup directories if they don't exist
mkdir -p "$FULL_BACKUP_DIR" "$INC_BACKUP_DIR" "$DIFF_BACKUP_DIR" "$INCSIZE_BACKUP_DIR"

# Ensure log file exists and is writable
touch "$LOG_FILE"
touch "$TS_STEP1" "$TS_STEP2" "$TS_STEP3" "$TS_STEP4" # Initialize timestamp files

# Initialize counters for backup files
FULL_COUNTER=1
INC_COUNTER=1
DIFF_COUNTER=1
INCSIZE_COUNTER=1

# Function to log messages
log_message() {
    echo "$(date '+%a %-d %b%Y %I:%M:%S %p %Z') $1" >> "$LOG_FILE"
    # Also print to console for debugging
    echo "$(date '+%a %-d %b%Y %I:%M:%S %p %Z') $1"
}

# Function to find files of specified types
find_files() {
    local search_dir="$1"
    local timestamp_file="$2"  # Now takes a timestamp file path
    local size_filter="$3"
    shift 3

    local find_cmd="find \"$search_dir\" -type f"

    # Exclude the log file itself
    local log_file_path="$LOG_FILE"
    find_cmd="$find_cmd -not -path \"$log_file_path\""

    # Exclude .local/share/CMakeTools directory
    find_cmd="$find_cmd -not -path \"$HOME/.local/share/CMakeTools\" -prune"

    # Add timestamp filter if provided (using -newer with timestamp file)
    if [ -n "$timestamp_file" ]; then
        find_cmd="$find_cmd -newer \"$timestamp_file\""
    fi

    # Add size filter if provided
    if [ -n "$size_filter" ]; then
        find_cmd="$find_cmd -size +${size_filter}k"
    fi

    # Add file extension filters if arguments were provided
    if [ $# -gt 0 ]; then
        find_cmd="$find_cmd \("
        first=true
        for ext in "$@"; do
            if $first; then
                find_cmd="$find_cmd -name \"*$ext\""
                first=false
            else
                find_cmd="$find_cmd -o -name \"*$ext\""
            fi
        done
        find_cmd="$find_cmd \)"
    fi

    # Execute the command
    eval "$find_cmd"
}
# Main backup loop
while true; do
    echo "Starting backup cycle..."

    # STEP 1: Full Backup
    echo "Performing STEP 1: Full Backup"
    touch "$TS_STEP1" # Update timestamp for STEP 1 start
    FULL_BACKUP_FILE="$FULL_BACKUP_DIR/fullbup-$FULL_COUNTER.tar"

    # Create temporary file for the list of files
    TEMP_FULL_LIST=$(mktemp)

    # Find files based on provided extensions
    if [ $# -eq 0 ]; then
        find_files "/home/$USERNAME" "" "" > "$TEMP_FULL_LIST" # No timestamp for full backup
    else
        find_files "/home/$USERNAME" "" "" "$@" > "$TEMP_FULL_LIST" # No timestamp for full backup
    fi

    # Check if we found any files
    if [ -s "$TEMP_FULL_LIST" ]; then
        # Create the tar file
        tar -cf "$FULL_BACKUP_FILE" -T "$TEMP_FULL_LIST" 2>/dev/null
        # Log the creation
        log_message "fullbup-$FULL_COUNTER.tar was created"
        FULL_COUNTER=$((FULL_COUNTER + 1))
    else
        log_message "No files found for Full backup"
    fi

    # Clean up
    rm -f "$TEMP_FULL_LIST"

    # Wait for 2 minutes
    echo "Waiting 2 minutes..."
    sleep 120 


    # --- Inside the main loop ---

# ... after STEP 1 ...

# Find files modified since STEP 1 ONCE
echo "Finding files changed since Step 1..."
TEMP_SINCE_STEP1_LIST=$(mktemp)
if [ $# -eq 0 ]; then
    find_files "/home/$USERNAME" "$TS_STEP1" "" > "$TEMP_SINCE_STEP1_LIST"
else
    find_files "/home/$USERNAME" "$TS_STEP1" "" "$@" > "$TEMP_SINCE_STEP1_LIST"
fi

# STEP 2: Incremental Backup 1
echo "Performing STEP 2: Incremental Backup 1"
touch "$TS_STEP2"
if [ -s "$TEMP_SINCE_STEP1_LIST" ]; then
    INC_BACKUP_FILE="$INC_BACKUP_DIR/incbup-$INC_COUNTER.tar"
    tar -cf "$INC_BACKUP_FILE" -T "$TEMP_SINCE_STEP1_LIST" 2>/dev/null
    log_message "incbup-$INC_COUNTER.tar was created"
    INC_COUNTER=$((INC_COUNTER + 1))
else
    log_message "No changes-Incremental backup 1 was not created"
fi
# DO NOT remove TEMP_SINCE_STEP1_LIST yet

echo "Waiting 2 minutes..."
sleep 120 

# STEP 3: Incremental Backup 2
echo "Performing STEP 3: Incremental Backup 2"
touch "$TS_STEP3"
TEMP_INC2_LIST=$(mktemp)
if [ $# -eq 0 ]; then
    find_files "/home/$USERNAME" "$TS_STEP2" "" > "$TEMP_INC2_LIST"
else
    find_files "/home/$USERNAME" "$TS_STEP2" "" "$@" > "$TEMP_INC2_LIST"
fi
if [ -s "$TEMP_INC2_LIST" ]; then
    INC_BACKUP_FILE="$INC_BACKUP_DIR/incbup-$INC_COUNTER.tar"
    tar -cf "$INC_BACKUP_FILE" -T "$TEMP_INC2_LIST" 2>/dev/null
    log_message "incbup-$INC_COUNTER.tar was created"
    INC_COUNTER=$((INC_COUNTER + 1))
else
    log_message "No changes-Incremental backup 2 was not created"
fi
rm -f "$TEMP_INC2_LIST"

echo "Waiting 2 minutes..."
sleep 120

# STEP 4: Differential Backup after STEP 1
echo "Performing STEP 4: Differential Backup"
touch "$TS_STEP4"
# REUSE the list from earlier
if [ -s "$TEMP_SINCE_STEP1_LIST" ]; then
    DIFF_BACKUP_FILE="$DIFF_BACKUP_DIR/diffbup-$DIFF_COUNTER.tar"
    tar -cf "$DIFF_BACKUP_FILE" -T "$TEMP_SINCE_STEP1_LIST" 2>/dev/null
    log_message "diffbup-$DIFF_COUNTER.tar was created"
    DIFF_COUNTER=$((DIFF_COUNTER + 1))
else
    log_message "No changes-Differential backup was not created"
fi
# NOW we can clean up the reused list
rm -f "$TEMP_SINCE_STEP1_LIST"

    # Wait for 2 minutes
    echo "Waiting 2 minutes..."
    sleep 120 

      # STEP 5: Incremental Size Backup after STEP 4 (files > 100kb)
    echo "Performing STEP 5: Incremental Size Backup"
    STEP5_TIME=$(date -Iseconds)

    # Create temporary file for the list of files
    TEMP_INCSIZE_LIST=$(mktemp)

    echo "DEBUG STEP 5: Timestamp File: $TS_STEP4"
    echo "DEBUG STEP 5: Size Filter: 100k"

    # Find files modified after STEP4 and larger than 100kb
    if [ $# -eq 0 ]; then
        find_files "/home/$USERNAME" "$TS_STEP4" "100" > "$TEMP_INCSIZE_LIST"
    else
        find_files "/home/$USERNAME" "$TS_STEP4" "100" "$@" > "$TEMP_INCSIZE_LIST"
    fi

    echo "DEBUG STEP 5: Files found by find command before tar:"
    cat "$TEMP_INCSIZE_LIST"

    # Check if we found any changed files that are larger than 100kb
    if [ -s "$TEMP_INCSIZE_LIST" ]; then
        # Create the tar file
        INCSIZE_BACKUP_FILE="$INCSIZE_BACKUP_DIR/incsizebup-$INCSIZE_COUNTER.tar"
        tar -cf "$INCSIZE_BACKUP_FILE" -T "$TEMP_INCSIZE_LIST" 2>/dev/null
        # Log the creation
        log_message "incsizebup-$INCSIZE_COUNTER.tar was created"
        INCSIZE_COUNTER=$((INCSIZE_COUNTER + 1))
    else
        log_message "No changes-Incremental size backup was not created"
    fi

    # Clean up
    rm -f "$TEMP_INCSIZE_LIST"

    # Loop back to STEP 1 after a 2-minute interval
    echo "Waiting 2 minutes before starting next cycle..."
    sleep 120 
done