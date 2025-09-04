#!/bin/bash

# Native messaging host wrapper for SwiftFetch
# This script handles the native messaging protocol

# Log file for debugging (comment out in production)
LOG_FILE="/tmp/swiftfetch-native.log"

# Function to log messages (for debugging)
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$LOG_FILE"
}

# Find the SwiftFetch app
if [ -f "/Applications/SwiftFetch.app/Contents/MacOS/SwiftFetch" ]; then
    APP_PATH="/Applications/SwiftFetch.app/Contents/MacOS/SwiftFetch"
else
    # Development path
    APP_PATH="/Users/devitripathy/Library/Developer/Xcode/DerivedData/SwiftFetch-*/Build/Products/Debug/SwiftFetch.app/Contents/MacOS/SwiftFetch"
    APP_PATH=$(ls -t $APP_PATH 2>/dev/null | head -1)
fi

log_message "Native host started with app path: $APP_PATH"

# Function to read native message
read_message() {
    # Read 4-byte message length (native messaging protocol)
    local len_bytes=$(head -c 4)
    
    # Convert to integer (little-endian)
    local len=$(printf "%d" "'$(echo "$len_bytes" | cut -c1-1)")
    
    # Read the actual message
    local message=$(head -c $len)
    
    echo "$message"
}

# Function to write native message
write_message() {
    local message="$1"
    local len=${#message}
    
    # Write message length as 4 bytes (little-endian)
    printf '%c%c%c%c' \
        $((len & 0xFF)) \
        $(((len >> 8) & 0xFF)) \
        $(((len >> 16) & 0xFF)) \
        $(((len >> 24) & 0xFF))
    
    # Write the message
    printf '%s' "$message"
}

# Simple message handler
while true; do
    # Read incoming message
    message=$(read_message)
    
    if [ -z "$message" ]; then
        log_message "Empty message received, exiting"
        break
    fi
    
    log_message "Received: $message"
    
    # Parse message type (simple JSON parsing)
    msg_type=$(echo "$message" | grep -o '"type":"[^"]*"' | cut -d'"' -f4)
    
    # Handle different message types
    case "$msg_type" in
        "ping")
            response='{"type":"pong","status":"connected"}'
            write_message "$response"
            log_message "Sent pong response"
            ;;
        "download")
            # Extract URL from message
            url=$(echo "$message" | grep -o '"url":"[^"]*"' | cut -d'"' -f4)
            
            # Send download to SwiftFetch via AppleScript
            osascript -e "tell application \"SwiftFetch\" to open location \"$url\""
            
            response='{"type":"download_started","success":true}'
            write_message "$response"
            log_message "Started download: $url"
            ;;
        *)
            response='{"type":"response","success":true}'
            write_message "$response"
            log_message "Handled message type: $msg_type"
            ;;
    esac
done

log_message "Native host exiting"