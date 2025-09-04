# Chrome Web Store Submission Guide

## Extension Package
- **File**: `swiftfetch-extension.zip` (11KB)
- **Extension ID**: `mdllhgebmaocbeagkopjjmcabalbiikh` (deterministic based on public key)
- **Manifest Version**: 3

## Store Listing Information

### Name
SwiftFetch Download Manager

### Short Description (132 chars max)
Supercharge downloads with SwiftFetch - multi-threaded downloads, browser integration, and advanced download management for macOS.

### Detailed Description
SwiftFetch brings powerful download management to Chrome with native macOS integration.

**Key Features:**
• **Right-click Downloads** - Send any link directly to SwiftFetch with a right-click
• **Auto-capture Large Files** - Automatically intercepts downloads over 10MB
• **Video Detection** - Detects videos on supported sites for easy downloading
• **Batch Downloads** - Download all links on a page with one click
• **Native macOS App** - Seamlessly integrates with the SwiftFetch desktop application

**How It Works:**
1. Install the SwiftFetch desktop app from swiftfetch.app
2. Add this extension to Chrome
3. Right-click any download link and select "Download with SwiftFetch"
4. Manage all downloads in the native SwiftFetch app

**Benefits:**
• Multi-threaded downloads for faster speeds
• Resume interrupted downloads
• Schedule downloads for later
• Organize downloads by category
• Advanced download queue management

### Category
Productivity

### Language
English

### Screenshots Required (1280x800 or 640x400)
1. Right-click context menu showing "Download with SwiftFetch"
2. Extension popup showing download stats
3. SwiftFetch app managing downloads
4. Batch download selection

### Icons Required
- 128x128 PNG icon (already in package)

### Privacy Policy URL
https://swiftfetch.app/privacy

### Permissions Justification
- **downloads**: Monitor and intercept downloads for management
- **contextMenus**: Add "Download with SwiftFetch" option
- **storage**: Save user preferences and settings
- **nativeMessaging**: Communicate with SwiftFetch desktop app
- **webRequest**: Detect downloadable content
- **tabs/activeTab**: Access current page for batch downloads
- **cookies**: Pass authentication for protected downloads
- **host_permissions <all_urls>**: Handle downloads from any website

## Publishing Checklist
- [ ] Create developer account ($5 one-time fee)
- [ ] Upload swiftfetch-extension.zip
- [ ] Add store listing information
- [ ] Upload screenshots
- [ ] Set up privacy policy page
- [ ] Submit for review

## Post-Publication Tasks
- [ ] Update SwiftFetchApp.swift with published extension URL
- [ ] Update BrowserIntegrationManager with Web Store URL
- [ ] Add "Get it on Chrome Web Store" badge to website
- [ ] Test installation flow from Web Store