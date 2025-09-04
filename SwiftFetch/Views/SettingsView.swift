import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var downloadManager: DownloadManager
    private enum Tabs: Hashable {
        case general, network, browser, categories, advanced
    }
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(Tabs.general)
            
            NetworkSettingsView()
                .tabItem {
                    Label("Network", systemImage: "network")
                }
                .tag(Tabs.network)
            
            BrowserSettingsView()
                .tabItem {
                    Label("Browser", systemImage: "globe")
                }
                .tag(Tabs.browser)
            
            CategoriesSettingsView()
                .tabItem {
                    Label("Categories", systemImage: "folder")
                }
                .tag(Tabs.categories)
            
            AdvancedSettingsView()
                .tabItem {
                    Label("Advanced", systemImage: "gearshape.2")
                }
                .tag(Tabs.advanced)
        }
        .frame(width: 700, height: 500)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("defaultDownloadPath") private var defaultPath = ""
    @AppStorage("maxConcurrentDownloads") private var maxConcurrent = 5
    @AppStorage("startDownloadsAutomatically") private var autoStart = true
    @AppStorage("playSound") private var playSound = true
    @AppStorage("showNotifications") private var showNotifications = true
    @AppStorage("removeCompletedAfter") private var removeCompletedAfter = 0
    
    var body: some View {
        Form {
            Section("Downloads") {
                HStack {
                    Text("Default download folder:")
                    Text(defaultPath.isEmpty ? "~/Downloads" : defaultPath)
                        .foregroundColor(.secondary)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Choose...") {
                        chooseFolder()
                    }
                }
                
                HStack {
                    Text("Maximum concurrent downloads:")
                    Stepper(value: $maxConcurrent, in: 1...20) {
                        Text("\(maxConcurrent)")
                            .monospacedDigit()
                    }
                }
                
                Toggle("Start downloads automatically", isOn: $autoStart)
            }
            
            Section("Notifications") {
                Toggle("Play sound when download completes", isOn: $playSound)
                Toggle("Show system notifications", isOn: $showNotifications)
            }
            
            Section("Cleanup") {
                Picker("Remove completed downloads:", selection: $removeCompletedAfter) {
                    Text("Never").tag(0)
                    Text("After 1 hour").tag(3600)
                    Text("After 1 day").tag(86400)
                    Text("After 1 week").tag(604800)
                }
            }
        }
        .padding()
    }
    
    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        
        if panel.runModal() == .OK {
            defaultPath = panel.url?.path ?? ""
        }
    }
}

struct NetworkSettingsView: View {
    @AppStorage("defaultSegments") private var defaultSegments = 8
    @AppStorage("maxConnectionsPerServer") private var maxConnections = 8
    @AppStorage("connectionTimeout") private var connectionTimeout = 30
    @AppStorage("retryCount") private var retryCount = 5
    @AppStorage("retryWait") private var retryWait = 5
    @AppStorage("globalSpeedLimit") private var globalSpeedLimit = 0
    @AppStorage("useProxy") private var useProxy = false
    @AppStorage("proxyType") private var proxyType = "HTTP"
    @AppStorage("proxyHost") private var proxyHost = ""
    @AppStorage("proxyPort") private var proxyPort = 8080
    @AppStorage("proxyUsername") private var proxyUsername = ""
    @AppStorage("proxyPassword") private var proxyPassword = ""
    
    var body: some View {
        Form {
            Section("Connection") {
                HStack {
                    Text("Default segments per file:")
                    Slider(value: Binding(
                        get: { Double(defaultSegments) },
                        set: { defaultSegments = Int($0) }
                    ), in: 1...16, step: 1)
                    Text("\(defaultSegments)")
                        .monospacedDigit()
                        .frame(width: 30)
                }
                
                HStack {
                    Text("Max connections per server:")
                    Stepper(value: $maxConnections, in: 1...16) {
                        Text("\(maxConnections)")
                            .monospacedDigit()
                    }
                }
                
                HStack {
                    Text("Connection timeout:")
                    TextField("", value: $connectionTimeout, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                    Text("seconds")
                }
                
                HStack {
                    Text("Retry failed downloads:")
                    Stepper(value: $retryCount, in: 0...10) {
                        Text("\(retryCount) times")
                            .monospacedDigit()
                    }
                }
                
                if retryCount > 0 {
                    HStack {
                        Text("Wait between retries:")
                        TextField("", value: $retryWait, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                        Text("seconds")
                    }
                }
            }
            
            Section("Speed Limits") {
                HStack {
                    Text("Global download speed limit:")
                    TextField("", value: $globalSpeedLimit, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                    Text("KB/s (0 = unlimited)")
                }
            }
            
            Section("Proxy") {
                Toggle("Use proxy server", isOn: $useProxy)
                
                if useProxy {
                    Picker("Type:", selection: $proxyType) {
                        Text("HTTP").tag("HTTP")
                        Text("HTTPS").tag("HTTPS")
                        Text("SOCKS5").tag("SOCKS5")
                    }
                    .pickerStyle(.segmented)
                    
                    HStack {
                        Text("Host:")
                        TextField("proxy.example.com", text: $proxyHost)
                            .textFieldStyle(.roundedBorder)
                        
                        Text("Port:")
                        TextField("", value: $proxyPort, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                    }
                    
                    HStack {
                        Text("Username:")
                        TextField("", text: $proxyUsername)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    HStack {
                        Text("Password:")
                        SecureField("", text: $proxyPassword)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
        }
        .padding()
    }
}

struct BrowserSettingsView: View {
    @AppStorage("interceptDownloads") private var interceptDownloads = true
    @AppStorage("minFileSizeToIntercept") private var minFileSize = 1
    @AppStorage("interceptedFileTypes") private var fileTypes = "zip,exe,dmg,iso,pdf,mp4,mkv"
    @State private var extensionStatus = ExtensionStatus()
    
    struct ExtensionStatus {
        var chrome = false
        var firefox = false
        var safari = false
        var edge = false
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Section("Extension Status") {
                VStack(alignment: .leading, spacing: 12) {
                    BrowserStatusRow(browser: "Chrome", installed: extensionStatus.chrome)
                    BrowserStatusRow(browser: "Firefox", installed: extensionStatus.firefox)
                    BrowserStatusRow(browser: "Safari", installed: extensionStatus.safari)
                    BrowserStatusRow(browser: "Edge", installed: extensionStatus.edge)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            
            Section("Download Interception") {
                Toggle("Intercept browser downloads", isOn: $interceptDownloads)
                
                if interceptDownloads {
                    HStack {
                        Text("Minimum file size:")
                        TextField("", value: $minFileSize, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                        Text("MB")
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("File types to intercept:")
                        TextEditor(text: $fileTypes)
                            .font(.system(.body, design: .monospaced))
                            .frame(height: 60)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                        Text("Comma-separated file extensions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            HStack {
                Button("Install Browser Extensions...") {
                    openExtensionInstructions()
                }
                
                Spacer()
                
                Button("Test Connection") {
                    testNativeMessaging()
                }
            }
        }
        .padding()
        .onAppear {
            checkExtensionStatus()
        }
    }
    
    func checkExtensionStatus() {
        // Check if native messaging hosts are installed
        // This would check for the manifest files in the appropriate directories
    }
    
    func openExtensionInstructions() {
        NSWorkspace.shared.open(URL(string: "https://swiftfetch.app/extensions")!)
    }
    
    func testNativeMessaging() {
        // Test native messaging connection
    }
}

struct BrowserStatusRow: View {
    let browser: String
    let installed: Bool
    
    var body: some View {
        HStack {
            Image(systemName: installed ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(installed ? .green : .gray)
            
            Text(browser)
            
            Spacer()
            
            if installed {
                Text("Connected")
                    .foregroundColor(.green)
                    .font(.caption)
            } else {
                Button("Install") {
                    // Open installation instructions
                }
                .buttonStyle(.link)
                .font(.caption)
            }
        }
    }
}

struct CategoriesSettingsView: View {
    @State private var categories: [Category] = []
    @State private var selectedCategory: Category?
    @State private var showingAddCategory = false
    
    var body: some View {
        HSplitView {
            // Category list
            List(selection: $selectedCategory) {
                ForEach(categories) { category in
                    Label(category.name, systemImage: category.icon)
                        .tag(category)
                }
            }
            .frame(minWidth: 200)
            
            // Category details
            if let category = selectedCategory {
                CategoryDetailView(category: category)
            } else {
                ContentUnavailableView {
                    Label("Select a Category", systemImage: "folder")
                } description: {
                    Text("Choose a category to configure its settings")
                }
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button(action: { showingAddCategory = true }) {
                    Image(systemName: "plus")
                }
                
                Button(action: removeCategory) {
                    Image(systemName: "minus")
                }
                .disabled(selectedCategory == nil)
            }
        }
        .sheet(isPresented: $showingAddCategory) {
            AddCategorySheet(categories: $categories)
        }
    }
    
    func removeCategory() {
        if let category = selectedCategory {
            categories.removeAll { $0.id == category.id }
            selectedCategory = nil
        }
    }
}

struct CategoryDetailView: View {
    let category: Category
    @State private var name: String = ""
    @State private var destination: URL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    @State private var namingTemplate = "{filename}"
    @State private var selectedIcon = "folder"
    @State private var selectedColor = "blue"
    
    var body: some View {
        Form {
            TextField("Name:", text: $name)
            
            HStack {
                Text("Destination:")
                Text(destination.path)
                    .foregroundColor(.secondary)
                    .truncationMode(.middle)
                Spacer()
                Button("Choose...") {
                    chooseDestination()
                }
            }
            
            TextField("Naming template:", text: $namingTemplate)
                .font(.system(.body, design: .monospaced))
            
            Text("Variables: {filename}, {date}, {time}, {domain}")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Text("Icon:")
                Picker("", selection: $selectedIcon) {
                    Image(systemName: "folder").tag("folder")
                    Image(systemName: "doc").tag("doc")
                    Image(systemName: "video").tag("video")
                    Image(systemName: "music.note").tag("music.note")
                    Image(systemName: "archivebox").tag("archivebox")
                }
                .pickerStyle(.segmented)
            }
            
            // Post-download actions would go here
        }
        .padding()
        .onAppear {
            name = category.name
            destination = category.destination
            selectedIcon = category.icon
        }
    }
    
    func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        
        if panel.runModal() == .OK {
            destination = panel.url ?? destination
        }
    }
}

struct AddCategorySheet: View {
    @Binding var categories: [Category]
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var destination = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    
    var body: some View {
        VStack(spacing: 20) {
            Text("New Category")
                .font(.title2)
                .fontWeight(.semibold)
            
            TextField("Name:", text: $name)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Text("Destination:")
                Text(destination.lastPathComponent)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Choose...") {
                    // Choose destination
                }
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                
                Spacer()
                
                Button("Add") {
                    let newCategory = Category(
                        id: categories.count + 1,
                        name: name,
                        destination: destination
                    )
                    categories.append(newCategory)
                    dismiss()
                }
                .disabled(name.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 200)
    }
}

struct AdvancedSettingsView: View {
    @AppStorage("aria2Path") private var aria2Path = "/usr/local/bin/aria2c"
    @AppStorage("aria2RPCPort") private var rpcPort = 6800
    @AppStorage("aria2Secret") private var rpcSecret = ""
    @AppStorage("enableLogging") private var enableLogging = false
    @AppStorage("logLevel") private var logLevel = "error"
    @State private var aria2Version = "Unknown"
    @State private var isDaemonRunning = false
    
    var body: some View {
        Form {
            Section("aria2 Configuration") {
                HStack {
                    Text("aria2 executable path:")
                    TextField("", text: $aria2Path)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse...") {
                        browseForAria2()
                    }
                }
                
                HStack {
                    Text("RPC Port:")
                    TextField("", value: $rpcPort, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
                
                HStack {
                    Text("RPC Secret:")
                    SecureField("Optional", text: $rpcSecret)
                        .textFieldStyle(.roundedBorder)
                }
                
                HStack {
                    Text("Status:")
                    Circle()
                        .fill(isDaemonRunning ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(isDaemonRunning ? "Running" : "Not Running")
                        .foregroundColor(isDaemonRunning ? .green : .red)
                    
                    Spacer()
                    
                    Button(isDaemonRunning ? "Restart" : "Start") {
                        toggleDaemon()
                    }
                }
                
                HStack {
                    Text("Version:")
                    Text(aria2Version)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Logging") {
                Toggle("Enable logging", isOn: $enableLogging)
                
                if enableLogging {
                    Picker("Log level:", selection: $logLevel) {
                        Text("Error").tag("error")
                        Text("Warning").tag("warn")
                        Text("Info").tag("info")
                        Text("Debug").tag("debug")
                    }
                    
                    Button("Open Log File") {
                        openLogFile()
                    }
                }
            }
            
            Section("Maintenance") {
                Button("Clear Download History") {
                    clearHistory()
                }
                
                Button("Reset All Settings") {
                    resetSettings()
                }
                .foregroundColor(.red)
            }
        }
        .padding()
        .onAppear {
            checkAria2Status()
        }
    }
    
    func browseForAria2() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.unixExecutable]
        
        if panel.runModal() == .OK {
            aria2Path = panel.url?.path ?? ""
        }
    }
    
    func toggleDaemon() {
        // Start or restart aria2 daemon
    }
    
    func checkAria2Status() {
        // Check if aria2 is running and get version
    }
    
    func openLogFile() {
        let logURL = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/SwiftFetch/swiftfetch.log")
        NSWorkspace.shared.open(logURL)
    }
    
    func clearHistory() {
        // Clear download history
    }
    
    func resetSettings() {
        // Reset all settings to defaults
    }
}

#Preview {
    SettingsView()
        .environmentObject(DownloadManager())
}