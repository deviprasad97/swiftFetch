# SwiftFetch Browser Integration - Local Testing Guide

## Prerequisites
- SwiftFetch app built and running
- Chrome browser installed
- Access to project source code

## Testing Flow

### Step 1: Launch SwiftFetch
```bash
# Kill any existing instances
pkill SwiftFetch

# Launch the app
open /Users/devitripathy/Library/Developer/Xcode/DerivedData/SwiftFetch-*/Build/Products/Debug/SwiftFetch.app
```

### Step 2: Verify Native Host Installation
The app automatically installs native messaging hosts on first launch. Verify by checking:

```bash
# Check for native host files
ls -la ~/Library/Application\ Support/Google/Chrome/NativeMessagingHosts/
ls -la ~/Library/Application\ Support/BraveSoftware/Brave-Browser/NativeMessagingHosts/
ls -la ~/Library/Application\ Support/Microsoft\ Edge/NativeMessagingHosts/

# You should see: com.swiftfetch.nativehost.json
```

### Step 3: Access Browser Integration Settings
1. Open SwiftFetch app
2. Press `⌘,` or go to SwiftFetch → Settings
3. Click on the **Browser** tab
4. You'll see the Browser Integration panel with:
   - Status for each browser (Chrome, Edge, Brave, Firefox)
   - Extension status
   - Install Extension button
   - Setup Instructions button

### Step 4: Install Chrome Extension (Local Development)

#### Method A: Through Settings UI
1. In Settings → Browser tab
2. Click **"Install Extension"** button
3. This will:
   - Open Chrome extensions page (chrome://extensions)
   - Open the extension folder in Finder
   - Show installation instructions

#### Method B: Manual Installation
1. Open Chrome and go to: `chrome://extensions/`
2. Enable **Developer mode** (toggle in top right)
3. Click **"Load unpacked"**
4. Navigate to: `/Users/devitripathy/code/download_manager/SwiftFetch/Extensions/Chrome`
5. Click **Select**

### Step 5: Verify Extension Installation
- Extension ID should be: `mdllhgebmaocbeagkopjjmcabalbiikh`
- Extension name: SwiftFetch Download Manager
- You should see the SwiftFetch icon in Chrome toolbar

### Step 6: Test Download Capture

#### Test 1: Right-Click Download
1. Go to any website with downloadable files
2. Right-click on a download link
3. Select **"Download with SwiftFetch"** from context menu
4. Download should appear in SwiftFetch app

#### Test 2: Direct Download (10MB+ files)
1. Visit: https://pub-821312cfd07a4061bf7b99c1f23ed29b.r2.dev/3dicons-png-dynamic-1.0.0.zip
2. Click the link normally
3. Files over 10MB are automatically captured
4. Download should redirect to SwiftFetch

#### Test 3: Extension Popup
1. Click the SwiftFetch extension icon in Chrome toolbar
2. You should see:
   - Connection status (Connected/Disconnected)
   - Active downloads count
   - Options to open SwiftFetch app

### Step 7: Test Browser Status Updates
1. Go back to SwiftFetch Settings → Browser tab
2. Click **"Refresh Status"** button
3. Chrome should show a green checkmark if extension is installed

### Step 8: Test Native Host Communication
```bash
# Check if native host is responding
echo '{"type":"ping"}' | /Users/devitripathy/Library/Developer/Xcode/DerivedData/SwiftFetch-*/Build/Products/Debug/SwiftFetch.app/Contents/MacOS/SwiftFetch
```

## Troubleshooting

### Extension Not Working
1. Check Chrome Console (Extension page → Details → Inspect service worker)
2. Look for errors in console
3. Verify native host is installed: `cat ~/Library/Application\ Support/Google/Chrome/NativeMessagingHosts/com.swiftfetch.nativehost.json`

### Native Host Not Found
1. Click **"Reinstall Native Host"** in Browser settings
2. Restart Chrome
3. Reload extension

### Downloads Not Captured
1. Verify SwiftFetch app is running
2. Check extension popup shows "Connected"
3. Try disabling other download manager extensions

## Testing Checklist

- [ ] App launches without errors
- [ ] Native hosts auto-install on first launch
- [ ] Browser tab in Settings shows correct status
- [ ] "Install Extension" button opens correct dialogs
- [ ] Extension loads in Chrome without errors
- [ ] Extension ID matches: `mdllhgebmaocbeagkopjjmcabalbiikh`
- [ ] Right-click "Download with SwiftFetch" works
- [ ] Large files (10MB+) are auto-captured
- [ ] Extension popup shows connection status
- [ ] Downloads appear in SwiftFetch app
- [ ] "Refresh Status" updates browser status
- [ ] "Reinstall Native Host" recreates manifest files

## Reset for Clean Testing
```bash
# Remove all SwiftFetch data
defaults delete com.swiftfetch.app

# Remove native host files
rm -f ~/Library/Application\ Support/*/NativeMessagingHosts/com.swiftfetch.nativehost.json

# Remove extension from Chrome
# Go to chrome://extensions/ and remove SwiftFetch

# Start fresh
open /Users/devitripathy/Library/Developer/Xcode/DerivedData/SwiftFetch-*/Build/Products/Debug/SwiftFetch.app
```

## Production vs Development
- **Development**: Extension loaded from local folder, shows "Install Extension" dialog with local instructions
- **Production**: Extension from Chrome Web Store, shows direct link to store page

The app detects if `/Users/devitripathy/code/download_manager/SwiftFetch/Extensions/Chrome` exists to determine environment.