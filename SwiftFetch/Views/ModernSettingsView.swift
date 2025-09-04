import SwiftUI

struct ModernSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = SettingsTab.general
    
    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case downloads = "Downloads"
        case browser = "Browser"
        case advanced = "Advanced"
        
        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .downloads: return "arrow.down.circle"
            case .browser: return "globe"
            case .advanced: return "wrench.and.screwdriver"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Title Bar
            HStack {
                Text("Settings")
                    .font(.system(size: 20, weight: .semibold))
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            
            Divider()
            
            // Tab Selector
            HStack(spacing: 2) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    SettingsTabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        action: { selectedTab = tab }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    switch selectedTab {
                    case .general:
                        ModernGeneralSettingsView()
                    case .downloads:
                        ModernDownloadSettingsView()
                    case .browser:
                        BrowserIntegrationView()
                    case .advanced:
                        ModernAdvancedSettingsView()
                    }
                }
                .padding(20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
            
            // Bottom Bar
            HStack {
                Button("Reset to Defaults") {
                    resetSettings()
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(width: 600, height: 500)
        .background(VisualEffectBackground())
    }
    
    func resetSettings() {
        // Reset all @AppStorage values to defaults
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
    }
}

struct SettingsTabButton: View {
    let tab: ModernSettingsView.SettingsTab
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                
                Text(tab.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ModernGeneralSettingsView: View {
    @AppStorage("launchAtStartup") private var launchAtStartup = false
    @AppStorage("showInMenuBar") private var showInMenuBar = true
    @AppStorage("showDockIcon") private var showDockIcon = true
    @AppStorage("checkForUpdates") private var checkForUpdates = true
    @AppStorage("theme") private var theme = "auto"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsSection(title: "Appearance") {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Theme", selection: $theme) {
                        Text("Auto").tag("auto")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.radioGroup)
                    
                    Toggle("Show in Menu Bar", isOn: $showInMenuBar)
                    Toggle("Show Dock Icon", isOn: $showDockIcon)
                }
            }
            
            SettingsSection(title: "Startup") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Launch at System Startup", isOn: $launchAtStartup)
                    Toggle("Check for Updates Automatically", isOn: $checkForUpdates)
                }
            }
        }
    }
}

struct ModernDownloadSettingsView: View {
    @AppStorage("defaultDownloadPath") private var defaultPath = ""
    @AppStorage("maxConcurrentDownloads") private var maxConcurrent = 5
    @AppStorage("defaultSegments") private var defaultSegments = 8
    @AppStorage("autoStartDownloads") private var autoStart = true
    @AppStorage("overwriteExisting") private var overwriteExisting = false
    @AppStorage("soundOnCompletion") private var soundOnCompletion = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsSection(title: "Download Location") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(defaultPath.isEmpty ? "~/Downloads" : defaultPath)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                        
                        Button("Choose...") {
                            chooseDownloadFolder()
                        }
                    }
                    
                    Toggle("Ask where to save each file", isOn: .constant(false))
                }
            }
            
            SettingsSection(title: "Download Behavior") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Concurrent Downloads")
                        Stepper("\(maxConcurrent)", value: $maxConcurrent, in: 1...10)
                    }
                    
                    HStack {
                        Text("Default Segments")
                        Stepper("\(defaultSegments)", value: $defaultSegments, in: 1...32)
                    }
                    
                    Toggle("Start Downloads Automatically", isOn: $autoStart)
                    Toggle("Overwrite Existing Files", isOn: $overwriteExisting)
                    Toggle("Play Sound on Completion", isOn: $soundOnCompletion)
                }
            }
        }
    }
    
    func chooseDownloadFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        
        if panel.runModal() == .OK, let url = panel.url {
            defaultPath = url.path
        }
    }
}

struct ModernBrowserSettingsView: View {
    @AppStorage("browserIntegration") private var browserIntegration = true
    @AppStorage("captureAllDownloads") private var captureAll = false
    @AppStorage("minFileSize") private var minFileSize = 1 // MB
    @State private var installedExtensions: Set<String> = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsSection(title: "Browser Integration") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable Browser Integration", isOn: $browserIntegration)
                    
                    Toggle("Capture All Downloads", isOn: $captureAll)
                        .disabled(!browserIntegration)
                    
                    HStack {
                        Text("Minimum File Size")
                        Stepper("\(minFileSize) MB", value: $minFileSize, in: 1...100)
                    }
                    .disabled(!browserIntegration)
                }
            }
            
            SettingsSection(title: "Browser Extensions") {
                VStack(alignment: .leading, spacing: 12) {
                    BrowserRow(browser: "Safari", isInstalled: installedExtensions.contains("safari"))
                    BrowserRow(browser: "Chrome", isInstalled: installedExtensions.contains("chrome"))
                    BrowserRow(browser: "Firefox", isInstalled: installedExtensions.contains("firefox"))
                    BrowserRow(browser: "Edge", isInstalled: installedExtensions.contains("edge"))
                }
            }
        }
    }
}

struct BrowserRow: View {
    let browser: String
    let isInstalled: Bool
    
    var browserIcon: String {
        switch browser {
        case "Safari": return "safari"
        case "Chrome": return "globe"
        case "Firefox": return "flame"
        case "Edge": return "network"
        default: return "globe"
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: browserIcon)
                .font(.system(size: 16))
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            Text(browser)
                .font(.system(size: 13))
            
            Spacer()
            
            if isInstalled {
                Label("Installed", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.green)
            } else {
                Button("Install") {
                    // Install extension
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
            }
        }
        .padding(.vertical, 4)
    }
}

struct ModernAdvancedSettingsView: View {
    @AppStorage("proxyEnabled") private var proxyEnabled = false
    @AppStorage("proxyHost") private var proxyHost = ""
    @AppStorage("proxyPort") private var proxyPort = ""
    @AppStorage("retryAttempts") private var retryAttempts = 3
    @AppStorage("connectionTimeout") private var connectionTimeout = 30
    @AppStorage("logLevel") private var logLevel = "info"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsSection(title: "Network") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Use Proxy", isOn: $proxyEnabled)
                    
                    if proxyEnabled {
                        HStack {
                            TextField("Host", text: $proxyHost)
                                .textFieldStyle(.roundedBorder)
                            TextField("Port", text: $proxyPort)
                                .frame(width: 80)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    
                    HStack {
                        Text("Connection Timeout")
                        Stepper("\(connectionTimeout) seconds", value: $connectionTimeout, in: 10...120, step: 10)
                    }
                    
                    HStack {
                        Text("Retry Attempts")
                        Stepper("\(retryAttempts)", value: $retryAttempts, in: 0...10)
                    }
                }
            }
            
            SettingsSection(title: "Logging") {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Log Level", selection: $logLevel) {
                        Text("Error").tag("error")
                        Text("Warning").tag("warning")
                        Text("Info").tag("info")
                        Text("Debug").tag("debug")
                    }
                    .pickerStyle(.segmented)
                    
                    HStack {
                        Button("Open Log Folder") {
                            openLogFolder()
                        }
                        
                        Button("Clear Logs") {
                            clearLogs()
                        }
                    }
                }
            }
        }
    }
    
    func openLogFolder() {
        if let url = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first {
            let logsURL = url.appendingPathComponent("Logs/SwiftFetch")
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: logsURL.path)
        }
    }
    
    func clearLogs() {
        // Clear log files
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
            
            content
                .padding(.leading, 16)
        }
    }
}