#!/bin/bash

# Auto-install SwiftFetch Chrome Extension and Native Host
# No manual extension ID needed!

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🚀 SwiftFetch Browser Integration Auto-Installer"
echo "================================================"

# The extension ID is deterministic based on the "key" field in manifest.json
# With our public key, the extension ID will always be:
EXTENSION_ID="mdllhgebmaocbeagkopjjmcabalbiikh"

APP_NAME="com.swiftfetch.nativehost"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
EXTENSION_DIR="$SCRIPT_DIR/../Extensions/Chrome"

# Check if SwiftFetch.app exists in Applications
if [ -f "/Applications/SwiftFetch.app/Contents/MacOS/SwiftFetch" ]; then
    HOST_PATH="/Applications/SwiftFetch.app/Contents/MacOS/SwiftFetch"
    echo -e "${GREEN}✅ Found SwiftFetch.app in Applications${NC}"
else
    # Use the debug build
    HOST_PATH="/Users/devitripathy/Library/Developer/Xcode/DerivedData/SwiftFetch-*/Build/Products/Debug/SwiftFetch.app/Contents/MacOS/SwiftFetch"
    HOST_PATH=$(ls -t $HOST_PATH 2>/dev/null | head -1)
    
    if [ -z "$HOST_PATH" ]; then
        echo -e "${RED}❌ SwiftFetch.app not found. Please build the app first.${NC}"
        exit 1
    fi
    echo -e "${YELLOW}⚠️  Using debug build: $HOST_PATH${NC}"
fi

# Create native host manifest
create_manifest() {
    cat <<EOF
{
  "name": "$APP_NAME",
  "description": "SwiftFetch Native Messaging Host",
  "path": "$HOST_PATH",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://$EXTENSION_ID/"
  ]
}
EOF
}

# Install for all Chromium-based browsers
install_for_browser() {
    local browser_name="$1"
    local native_host_dir="$2"
    
    if [ -d "$(dirname "$native_host_dir")" ]; then
        mkdir -p "$native_host_dir"
        create_manifest > "$native_host_dir/$APP_NAME.json"
        echo -e "${GREEN}  ✅ Installed for $browser_name${NC}"
        return 0
    else
        echo -e "  ⏭️  Skipping $browser_name (not installed)"
        return 1
    fi
}

echo ""
echo "📦 Installing Native Messaging Host..."
echo "Extension ID: $EXTENSION_ID"
echo ""

# Install for various browsers
install_for_browser "Chrome" "$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
install_for_browser "Chrome Beta" "$HOME/Library/Application Support/Google/Chrome Beta/NativeMessagingHosts"
install_for_browser "Chrome Canary" "$HOME/Library/Application Support/Google/Chrome Canary/NativeMessagingHosts"
install_for_browser "Microsoft Edge" "$HOME/Library/Application Support/Microsoft Edge/NativeMessagingHosts"
install_for_browser "Brave" "$HOME/Library/Application Support/BraveSoftware/Brave-Browser/NativeMessagingHosts"
install_for_browser "Chromium" "$HOME/Library/Application Support/Chromium/NativeMessagingHosts"

echo ""
echo "📂 Extension Installation Instructions:"
echo "======================================="
echo ""
echo "1. Open Chrome and go to: chrome://extensions/"
echo "2. Enable 'Developer mode' (toggle in top right)"
echo "3. Click 'Load unpacked'"
echo "4. Select this folder: $EXTENSION_DIR"
echo ""
echo "The extension ID should be: ${GREEN}$EXTENSION_ID${NC}"
echo ""
echo "5. Test it:"
echo "   - Click the SwiftFetch extension icon"
echo "   - Visit any page with downloads"
echo "   - Right-click a link → 'Download with SwiftFetch'"
echo ""
echo -e "${GREEN}✅ Installation complete!${NC}"
echo ""
echo "If you have issues, check:"
echo "  • SwiftFetch app is running"
echo "  • Extension is enabled in Chrome"
echo "  • Native host manifest files are in place:"
find "$HOME/Library/Application Support" -name "$APP_NAME.json" 2>/dev/null | while read -r file; do
    echo "    - $file"
done