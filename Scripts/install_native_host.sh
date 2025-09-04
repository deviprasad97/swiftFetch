#!/bin/bash

# Install Native Messaging Host for SwiftFetch
# This script registers the native host with Chrome, Edge, Firefox, and other browsers

set -e

APP_NAME="com.swiftfetch.nativehost"
HOST_PATH="/Applications/SwiftFetch.app/Contents/MacOS/SwiftFetch"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Get the extension ID (you need to update this after installing the extension)
EXTENSION_ID="${1:-YOUR_EXTENSION_ID_HERE}"

echo "🚀 Installing SwiftFetch Native Messaging Host..."
echo "📦 Extension ID: $EXTENSION_ID"

# Native messaging manifest
create_manifest() {
    local extension_id="$1"
    cat <<EOF
{
  "name": "$APP_NAME",
  "description": "SwiftFetch Native Messaging Host",
  "path": "$HOST_PATH",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://$extension_id/"
  ]
}
EOF
}

# Function to install manifest
install_manifest() {
    local dir="$1"
    local browser="$2"
    local extension_id="$3"
    
    if [ ! -d "$(dirname "$dir")" ]; then
        echo "  ⏭️  Skipping $browser (not installed)"
        return
    fi
    
    mkdir -p "$dir"
    create_manifest "$extension_id" > "$dir/$APP_NAME.json"
    echo "  ✅ Installed for $browser"
}

# Chrome installation paths
CHROME_PATHS=(
    "$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
    "$HOME/Library/Application Support/Google/Chrome Beta/NativeMessagingHosts"
    "$HOME/Library/Application Support/Google/Chrome Canary/NativeMessagingHosts"
)

# Install for Chrome variants
for chrome_path in "${CHROME_PATHS[@]}"; do
    browser_name=$(echo "$chrome_path" | sed 's/.*\/Google\/\(.*\)\/NativeMessagingHosts/\1/')
    install_manifest "$chrome_path" "Chrome $browser_name" "$EXTENSION_ID"
done

# Microsoft Edge
EDGE_PATH="$HOME/Library/Application Support/Microsoft Edge/NativeMessagingHosts"
install_manifest "$EDGE_PATH" "Microsoft Edge" "$EXTENSION_ID"

# Brave Browser
BRAVE_PATH="$HOME/Library/Application Support/BraveSoftware/Brave-Browser/NativeMessagingHosts"
install_manifest "$BRAVE_PATH" "Brave" "$EXTENSION_ID"

# Chromium
CHROMIUM_PATH="$HOME/Library/Application Support/Chromium/NativeMessagingHosts"
install_manifest "$CHROMIUM_PATH" "Chromium" "$EXTENSION_ID"

# Firefox (different manifest format)
FIREFOX_PATH="$HOME/Library/Application Support/Mozilla/NativeMessagingHosts"
if [ -d "$(dirname "$FIREFOX_PATH")" ]; then
    mkdir -p "$FIREFOX_PATH"
    cat <<EOF > "$FIREFOX_PATH/$APP_NAME.json"
{
  "name": "$APP_NAME",
  "description": "SwiftFetch Native Messaging Host",
  "path": "$HOST_PATH",
  "type": "stdio",
  "allowed_extensions": [
    "swiftfetch@extension"
  ]
}
EOF
    echo "  ✅ Installed for Firefox"
fi

echo ""
echo "✅ Installation complete!"
echo ""
echo "📝 Next steps:"
echo "1. Install the SwiftFetch Chrome extension from the Extensions/Chrome folder"
echo "2. Copy the extension ID from chrome://extensions (Developer mode ON)"
echo "3. Re-run this script with the extension ID:"
echo "   $0 YOUR_ACTUAL_EXTENSION_ID"
echo ""
echo "Manifest locations:"
find "$HOME/Library/Application Support" -name "$APP_NAME.json" 2>/dev/null | while read -r file; do
    echo "  - $file"
done