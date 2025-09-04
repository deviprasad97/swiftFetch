# SwiftFetch - Modern Download Manager for macOS

SwiftFetch is a powerful, native macOS download manager powered by aria2 with browser integration and advanced features.

## Features

- 🚀 **High-Performance Downloads**: Powered by aria2 engine for fast, segmented downloads
- 🎨 **Modern macOS UI**: Beautiful SwiftUI interface with card and list views
- 🔗 **Browser Integration**: Chrome extension for seamless download capture
- 📊 **Real-time Progress**: Live speed graphs and detailed statistics
- 💾 **Persistent Storage**: SQLite database for download history
- 🎬 **Video Downloads**: yt-dlp integration for video streaming sites (coming soon)
- 🔄 **Auto-resume**: Automatic resumption of interrupted downloads
- 📁 **Smart Categorization**: Auto-organize by file type

## Installation

### Main Application

1. Build the project in Xcode:
```bash
open SwiftFetch.xcodeproj
# Build and Run (⌘R)
```

2. The app will automatically:
   - Create necessary directories
   - Initialize the database
   - Start aria2 daemon
   - Set up download management

### Chrome Extension Installation

1. **Build the extension**:
```bash
cd Extensions/Chrome
# Extension files are already created
```

2. **Load in Chrome**:
   - Open Chrome and go to `chrome://extensions/`
   - Enable "Developer mode" (top right)
   - Click "Load unpacked"
   - Select the `/Extensions/Chrome` folder
   - The SwiftFetch extension icon should appear in your toolbar

3. **Configure Native Messaging Host**:
```bash
# Run the installation script
./Scripts/install_native_host.sh
```

This creates the native messaging manifest at:
- `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.swiftfetch.app.json`

4. **Test the extension**:
   - Right-click any download link
   - Select "Download with SwiftFetch"
   - The download should appear in the SwiftFetch app

## Usage

### Basic Operations

- **Add Download**: Click the + button or use ⌘N
- **Pause/Resume**: Click the pause/play button on any download
- **View Modes**: Toggle between Card and List view
- **Search**: Use the search bar to filter downloads
- **Categories**: Use sidebar to filter by status or file type

### Keyboard Shortcuts

- `⌘N` - New download
- `⌘O` - Import from file
- `⌘⇧B` - Batch import URLs
- `⌘,` - Settings
- `Delete` - Remove selected downloads

### Browser Integration

With the Chrome extension installed:
- **Context Menu**: Right-click links/media → "Download with SwiftFetch"
- **Auto-capture**: Large files automatically redirected to SwiftFetch
- **Video Detection**: Streaming videos detected and downloadable

## Architecture

```
SwiftFetch/
├── SwiftFetch/          # Main macOS app
│   ├── Models/          # Data models
│   ├── Views/           # SwiftUI views
│   ├── Services/        # Core services (aria2, database)
│   └── Resources/       # Bundled aria2 binary
├── Extensions/
│   └── Chrome/          # Chrome extension
├── NativeHost/          # Native messaging host
└── Scripts/             # Installation scripts
```

## Requirements

- macOS 14.0+
- Xcode 15.0+
- Chrome (for browser extension)

## Development

### Building from Source

```bash
git clone [repository]
cd SwiftFetch
open SwiftFetch.xcodeproj
```

### Adding New Features

1. **Download Engines**: Extend `Aria2Client.swift`
2. **UI Components**: Add views in `Views/`
3. **Browser Support**: Modify extension in `Extensions/Chrome/`

## Troubleshooting

### Downloads not starting
- Check if aria2 is running: `ps aux | grep aria2`
- Verify port 6800 is available: `lsof -i :6800`

### Extension not working
- Ensure native host is installed: Check `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/`
- Check Chrome DevTools console for errors
- Verify SwiftFetch app is running

### Database issues
- Database location: `~/Library/Containers/com.swiftfetch.app/Data/Library/Application Support/SwiftFetch/`
- Reset database: Delete `SwiftFetch.db` and restart app

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## License

[Your License Here]

## Credits

- Powered by [aria2](https://aria2.github.io/)
- Built with SwiftUI and Swift
- Icon designs from SF Symbols