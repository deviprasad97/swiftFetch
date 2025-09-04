# SwiftFetch - Modern Download Manager for macOS

## Project Overview
SwiftFetch is a native macOS download manager built with SwiftUI that provides high-performance downloads via the aria2 engine, browser integration through Chrome extensions, and a modern user interface.

## Key Architecture Components

### 1. Main Application (`/SwiftFetch`)
- **SwiftFetchApp.swift**: Main app entry point with URL scheme handling and window management
- **Models/**: Core data models for downloads
- **Views/**: SwiftUI views including ModernContentView (main UI)
- **Services/**: 
  - `Aria2Client.swift`: Interface to aria2 download engine
  - `DatabaseManager.swift`: SQLite persistence layer
  - `DownloadManager.swift`: Central download orchestration
  - `NativeMessagingHandler.swift`: Chrome extension communication
  - `BrowserBridge.swift`: Browser integration coordination
  - `BrowserIntegrationManager.swift`: Extension setup and configuration

### 2. Browser Extension (`/Extensions/Chrome`)
- Chrome extension for intercepting downloads
- Communicates via native messaging protocol
- Extension ID varies by build:
  - Debug: `pgbhajnajdnlkcpkjbfjoogjpdgeocdb`
  - Production: `mdllhgebmaocbeagkopjjmcabalbiikh`

### 3. Native Messaging
- Uses Chrome's native messaging protocol (4-byte length header + JSON)
- Native host manifest at: `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.swiftfetch.nativehost.json`
- App detects native messaging mode via stdin pipe check

## Critical Implementation Details

### URL Scheme Registration
- Registers `swiftfetch://` URL scheme for browser-to-app communication
- Handled in `SwiftFetchApp.swift` via `LSSetDefaultHandlerForURLScheme`
- Downloads passed as: `swiftfetch://download?url=...&filename=...`

### Window Management
- Uses `WindowGroup` with `handlesExternalEvents` to prevent duplicate windows
- `AppDelegate` manages window reopening behavior
- URL events handled via `.onOpenURL` modifier

### Build Configuration
- Debug builds use local DerivedData paths
- Release builds expect installation in `/Applications/SwiftFetch.app`
- aria2 binary bundled in `Resources/` folder

## Common Issues & Solutions

### Extension "Access Forbidden" Error
- Usually caused by extension ID mismatch in native host manifest
- Check Chrome's actual extension ID and update manifest's `allowed_origins`

### Multiple Windows Opening
- Ensure proper window management in `AppDelegate`
- Use `handlesExternalEvents` on WindowGroup
- Activate existing windows instead of creating new ones

### Native Messaging Disconnects
- Verify native host manifest path points to correct location
- Check that app binary exists at the specified path
- Ensure proper message handling for all Chrome message types

## Testing & Development

### Chrome Extension Testing
1. Load unpacked extension from `/Extensions/Chrome`
2. Note the generated extension ID
3. Update native host manifest if needed
4. Test via right-click → "Download with SwiftFetch"

### Build Commands
```bash
# Debug build
xcodebuild -project SwiftFetch.xcodeproj -scheme SwiftFetch -configuration Debug build

# Release build  
xcodebuild -project SwiftFetch.xcodeproj -scheme SwiftFetch -configuration Release build
```

### Key Paths
- Database: `~/Library/Containers/com.swiftfetch.app/Data/Library/Application Support/SwiftFetch/`
- Native Host Manifest: `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/`
- aria2 RPC: `localhost:6800`

## Code Style Guidelines
- Use SwiftUI for all new UI components
- Follow existing patterns for view models and services
- Maintain separation between UI and business logic
- Use async/await for asynchronous operations
- Prefer editing existing files over creating new ones

## Important Notes
- The app handles both standalone operation and browser-triggered downloads
- Native messaging mode is detected automatically on launch
- All downloads are persisted in SQLite database
- aria2 daemon runs as a subprocess managed by the app
- Browser cookies and headers are preserved for authenticated downloads