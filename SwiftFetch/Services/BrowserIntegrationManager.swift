import Foundation
import AppKit

class BrowserIntegrationManager {
    static let shared = BrowserIntegrationManager()
    
    private let nativeHostID = "com.swiftfetch.nativehost"
    
    // Extension IDs - Support multiple IDs for different installations
    private var extensionIDs: [String] {
        var ids = [String]()
        
        #if DEBUG
        // Development ID (unpacked)
        ids.append("pgbhajnajdnlkcpkjbfjoogjpdgeocdb")
        #endif
        
        // Check for user-configured production ID
        if let userConfiguredID = UserDefaults.standard.string(forKey: "ProductionExtensionID"),
           !userConfiguredID.isEmpty {
            ids.append(userConfiguredID)
        }
        
        // Default production ID - NOTE: This will need to be updated after Chrome Web Store publication
        // Users can configure the actual ID through the app settings
        ids.append("mdllhgebmaocbeagkopjjmcabalbiikh")
        
        return ids
    }
    private let chromeWebStoreURL = "https://chrome.google.com/webstore/detail/swiftfetch/mdllhgebmaocbeagkopjjmcabalbiikh"
    
    // Configure production extension ID (called after Chrome Web Store publication)
    func configureProductionExtensionID(_ id: String) {
        UserDefaults.standard.set(id, forKey: "ProductionExtensionID")
        print("✅ Configured production extension ID: \(id)")
        
        // Reinstall native hosts with new ID
        installNativeHostForAllBrowsers()
    }
    
    // Get current production extension ID
    func getProductionExtensionID() -> String? {
        return UserDefaults.standard.string(forKey: "ProductionExtensionID")
    }
    
    // Check if browser integration is set up
    func checkIntegrationStatus() -> BrowserIntegrationStatus {
        var status = BrowserIntegrationStatus()
        
        // Check if native host is installed for each browser
        status.chromeInstalled = isNativeHostInstalled(for: .chrome)
        status.edgeInstalled = isNativeHostInstalled(for: .edge)
        status.braveInstalled = isNativeHostInstalled(for: .brave)
        status.firefoxInstalled = isNativeHostInstalled(for: .firefox)
        
        return status
    }
    
    // Auto-install native messaging host on first launch
    func setupBrowserIntegration() {
        print("🚀 Setting up browser integration...")
        
        // Check if already set up
        if UserDefaults.standard.bool(forKey: "BrowserIntegrationCompleted") {
            print("✅ Browser integration already set up")
            return
        }
        
        // Install native host for all browsers
        installNativeHostForAllBrowsers()
        
        // Mark as completed
        UserDefaults.standard.set(true, forKey: "BrowserIntegrationCompleted")
        
        // Show notification to user
        showSetupCompleteNotification()
    }
    
    // Install native host manifest for all browsers
    private func installNativeHostForAllBrowsers() {
        let browsers: [Browser] = [.chrome, .chromeBeta, .chromeCanary, .edge, .brave, .chromium, .firefox]
        
        for browser in browsers {
            if isBrowserInstalled(browser) {
                installNativeHost(for: browser)
            }
        }
    }
    
    // Install native host for specific browser
    private func installNativeHost(for browser: Browser) {
        let manifestPath = getNativeHostPath(for: browser)
        let manifestDir = manifestPath.deletingLastPathComponent()
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: manifestDir, withIntermediateDirectories: true)
        
        // Create manifest
        let manifest = createManifest(for: browser)
        
        // Write manifest
        do {
            let data = try JSONSerialization.data(withJSONObject: manifest, options: .prettyPrinted)
            try data.write(to: manifestPath)
            print("✅ Installed native host for \(browser.displayName)")
        } catch {
            print("❌ Failed to install native host for \(browser.displayName): \(error)")
        }
    }
    
    // Create manifest JSON
    private func createManifest(for browser: Browser) -> [String: Any] {
        // Use the actual installed app path
        let appPath = Bundle.main.executablePath ?? "/Applications/SwiftFetch.app/Contents/MacOS/SwiftFetch"
        
        if browser == .firefox {
            // Firefox uses different format
            return [
                "name": nativeHostID,
                "description": "SwiftFetch Native Messaging Host",
                "path": appPath,
                "type": "stdio",
                "allowed_extensions": ["swiftfetch@extension"]
            ]
        } else {
            // Chromium-based browsers - Support multiple extension IDs
            let allowedOrigins = extensionIDs.map { "chrome-extension://\($0)/" }
            return [
                "name": nativeHostID,
                "description": "SwiftFetch Native Messaging Host",
                "path": appPath,
                "type": "stdio",
                "allowed_origins": allowedOrigins
            ]
        }
    }
    
    // Get native host manifest path for browser
    private func getNativeHostPath(for browser: Browser) -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let appSupport = home.appendingPathComponent("Library/Application Support")
        
        let browserPath: String
        switch browser {
        case .chrome:
            browserPath = "Google/Chrome/NativeMessagingHosts"
        case .chromeBeta:
            browserPath = "Google/Chrome Beta/NativeMessagingHosts"
        case .chromeCanary:
            browserPath = "Google/Chrome Canary/NativeMessagingHosts"
        case .edge:
            browserPath = "Microsoft Edge/NativeMessagingHosts"
        case .brave:
            browserPath = "BraveSoftware/Brave-Browser/NativeMessagingHosts"
        case .chromium:
            browserPath = "Chromium/NativeMessagingHosts"
        case .firefox:
            browserPath = "Mozilla/NativeMessagingHosts"
        }
        
        return appSupport
            .appendingPathComponent(browserPath)
            .appendingPathComponent("\(nativeHostID).json")
    }
    
    // Check if browser is installed
    private func isBrowserInstalled(_ browser: Browser) -> Bool {
        let appPaths = browser.applicationPaths
        return appPaths.contains { FileManager.default.fileExists(atPath: $0) }
    }
    
    // Check if native host is installed for browser
    private func isNativeHostInstalled(for browser: Browser) -> Bool {
        let manifestPath = getNativeHostPath(for: browser)
        return FileManager.default.fileExists(atPath: manifestPath.path)
    }
    
    // Open browser extension installation page
    func openExtensionInstallPage() {
        // First check if extension is already installed by trying native messaging
        if tryConnectToExtension() {
            showAlert(title: "Extension Already Installed", 
                     message: "The SwiftFetch browser extension is already installed and working!")
            return
        }
        
        // Open Chrome Web Store page
        if let url = URL(string: chromeWebStoreURL) {
            NSWorkspace.shared.open(url)
        }
    }
    
    // Try to connect to extension
    private func tryConnectToExtension() -> Bool {
        // This would actually use native messaging
        // For now, return false to indicate extension not installed
        return false
    }
    
    // Show notification
    private func showSetupCompleteNotification() {
        // Modern notification using UserNotifications framework would require additional setup
        // For now, we'll skip the notification as the app shows a welcome dialog instead
        print("✅ Browser integration setup complete")
    }
    
    // Show alert dialog
    private func showAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    // Browser enum
    enum Browser {
        case chrome, chromeBeta, chromeCanary, edge, brave, chromium, firefox
        
        var displayName: String {
            switch self {
            case .chrome: return "Chrome"
            case .chromeBeta: return "Chrome Beta"
            case .chromeCanary: return "Chrome Canary"
            case .edge: return "Microsoft Edge"
            case .brave: return "Brave"
            case .chromium: return "Chromium"
            case .firefox: return "Firefox"
            }
        }
        
        var applicationPaths: [String] {
            switch self {
            case .chrome:
                return ["/Applications/Google Chrome.app"]
            case .chromeBeta:
                return ["/Applications/Google Chrome Beta.app"]
            case .chromeCanary:
                return ["/Applications/Google Chrome Canary.app"]
            case .edge:
                return ["/Applications/Microsoft Edge.app"]
            case .brave:
                return ["/Applications/Brave Browser.app"]
            case .chromium:
                return ["/Applications/Chromium.app"]
            case .firefox:
                return ["/Applications/Firefox.app"]
            }
        }
    }
}

// Browser integration status
struct BrowserIntegrationStatus {
    var chromeInstalled = false
    var edgeInstalled = false
    var braveInstalled = false
    var firefoxInstalled = false
    
    var isAnyBrowserSetup: Bool {
        chromeInstalled || edgeInstalled || braveInstalled || firefoxInstalled
    }
}