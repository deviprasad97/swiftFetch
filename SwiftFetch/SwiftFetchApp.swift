import SwiftUI
// TODO: Add Sparkle for auto-updates
// import Sparkle

@main
struct SwiftFetchApp: App {
    @StateObject private var downloadManager = DownloadManager()
    @StateObject private var browserBridge = BrowserBridge()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Check if running in native messaging mode
        if NativeMessagingHandler.isNativeMessagingMode() {
            // Handle native messaging and exit
            NativeMessagingHandler.shared.startNativeMessaging()
            exit(0)
        }
        
        // Set up browser integration on first launch
        setupBrowserIntegration()
    }
    
    // TODO: Enable when Sparkle is added
    // private let updaterController = SPUStandardUpdaterController(
    //     startingUpdater: true,
    //     updaterDelegate: nil,
    //     userDriverDelegate: nil
    // )
    
    var body: some Scene {
        WindowGroup {
            ModernContentView()
                .environmentObject(downloadManager)
                .environmentObject(browserBridge)
                .onAppear {
                    setupApplication()
                }
                .handlesExternalEvents(preferring: Set(["*"]), allowing: Set(["*"]))
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.automatic)
        .commands {
            // TODO: Enable when Sparkle is added
            // CommandGroup(after: .appInfo) {
            //     CheckForUpdatesView(updater: updaterController.updater)
            // }
            
            CommandGroup(replacing: .newItem) {
                Button("New Download...") {
                    downloadManager.showNewDownloadSheet = true
                }
                .keyboardShortcut("N", modifiers: .command)
                
                Divider()
                
                Button("Import from File...") {
                    downloadManager.importFromFile()
                }
                .keyboardShortcut("O", modifiers: .command)
                
                Button("Import Batch URLs...") {
                    downloadManager.showBatchImport = true
                }
                .keyboardShortcut("B", modifiers: [.command, .shift])
            }
        }
        
        Settings {
            ModernSettingsView()
                .environmentObject(downloadManager)
        }
    }
    
    private func setupApplication() {
        // Register as default handler for swiftfetch:// URLs
        registerAsDefaultURLHandler()
        
        // TODO: Configure Sparkle updater when added
        // updaterController.updater.automaticallyChecksForUpdates = true
        // updaterController.updater.updateCheckInterval = 86400 // Daily
        
        // Start daemon if not running
        Task {
            await downloadManager.initialize()
        }
        
        // Register for browser messages
        Task { @MainActor in
            browserBridge.onDownloadRequest = { request in
                Task {
                    await downloadManager.handleBrowserDownload(request)
                }
            }
        }
    }
    
    private func setupBrowserIntegration() {
        // Set up native messaging hosts automatically
        BrowserIntegrationManager.shared.setupBrowserIntegration()
        
        // Check if this is first launch
        if !UserDefaults.standard.bool(forKey: "HasShownWelcome") {
            UserDefaults.standard.set(true, forKey: "HasShownWelcome")
            
            // Show welcome window on first launch
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                showWelcomeWindow()
            }
        }
    }
    
    private func showWelcomeWindow() {
        let alert = NSAlert()
        alert.messageText = "Welcome to SwiftFetch!"
        alert.informativeText = """
        SwiftFetch is now ready to handle your downloads.
        
        To enable browser integration:
        1. Click 'Install Extension' below
        2. Add the extension to Chrome
        3. Start downloading with SwiftFetch!
        
        You can also right-click any download link and select 'Download with SwiftFetch'.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Install Extension")
        alert.addButton(withTitle: "Later")
        
        if alert.runModal() == .alertFirstButtonReturn {
            BrowserIntegrationManager.shared.openExtensionInstallPage()
        }
    }
    
    private func registerAsDefaultURLHandler() {
        // Force registration as handler for swiftfetch:// URLs
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        
        // Use LSSetDefaultHandlerForURLScheme to register
        let result = LSSetDefaultHandlerForURLScheme("swiftfetch" as CFString, bundleID as CFString)
        
        if result == noErr {
            print("✅ Successfully registered as handler for swiftfetch:// URLs")
        } else {
            print("⚠️ Failed to register as URL handler: \(result)")
        }
    }
}

// App Delegate for window management
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // If no windows are visible, show the main window
        if !flag {
            for window in sender.windows {
                window.makeKeyAndOrderFront(nil)
            }
        }
        return true
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure we're the default handler for swiftfetch:// URLs
        if let bundleID = Bundle.main.bundleIdentifier {
            LSSetDefaultHandlerForURLScheme("swiftfetch" as CFString, bundleID as CFString)
        }
    }
    
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        // Prevent creating new untitled windows
        return false
    }
    
    func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
        // Just activate the existing window
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
        return true
    }
}

// TODO: Enable when Sparkle is added
// struct CheckForUpdatesView: View {
//     let updater: SPUUpdater
//     
//     var body: some View {
//         Button("Check for Updates...") {
//             updater.checkForUpdates()
//         }
//         .disabled(!updater.canCheckForUpdates)
//     }
// }