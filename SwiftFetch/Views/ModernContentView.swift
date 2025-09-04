import SwiftUI

struct ModernContentView: View {
    @EnvironmentObject var downloadManager: DownloadManager
    @State private var selectedCategory: SidebarCategory = .all
    @State private var searchText = ""
    @State private var showingSettings = false
    @State private var showingNewDownload = false
    @State private var showingBatchImport = false
    @State private var showingBrowserDownload = false
    @State private var browserDownloadRequest: BrowserDownloadRequest?
    @State private var viewMode: ViewMode = .card
    
    enum ViewMode: String, CaseIterable {
        case card = "Card"
        case list = "List"
        
        var icon: String {
            switch self {
            case .card: return "square.grid.2x2"
            case .list: return "list.bullet"
            }
        }
    }
    
    enum SidebarCategory: String, CaseIterable, Hashable {
        case all = "All Downloads"
        case active = "Active"
        case queued = "Queued"
        case completed = "Completed"
        case documents = "Documents"
        case videos = "Videos"
        case music = "Music"
        case archives = "Archives"
        case software = "Software"
        
        var icon: String {
            switch self {
            case .all: return "arrow.down.circle.fill"
            case .active: return "bolt.circle.fill"
            case .queued: return "clock.fill"
            case .completed: return "checkmark.circle.fill"
            case .documents: return "doc.fill"
            case .videos: return "video.fill"
            case .music: return "music.note"
            case .archives: return "archivebox.fill"
            case .software: return "app.fill"
            }
        }
        
        var filterKey: String {
            switch self {
            case .all: return "all"
            case .active: return "active"
            case .queued: return "queued"
            case .completed: return "completed"
            case .documents: return "category.documents"
            case .videos: return "category.videos"
            case .music: return "category.music"
            case .archives: return "category.archives"
            case .software: return "category.software"
            }
        }
        
        @MainActor func badge(for manager: DownloadManager) -> Int {
            switch self {
            case .all: return manager.tasks.count
            case .active: return manager.activeTasks.count
            case .queued: return manager.queuedTasks.count
            case .completed: return manager.completedTasks.count
            default: return 0
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            // Modern Sidebar
            List(selection: $selectedCategory) {
                Section("Downloads") {
                    ForEach([SidebarCategory.all, .active, .queued, .completed], id: \.self) { category in
                        SidebarRow(
                            category: category,
                            badge: category.badge(for: downloadManager),
                            isSelected: selectedCategory == category
                        )
                        .tag(category)
                    }
                }
                
                Section("Categories") {
                    ForEach([SidebarCategory.documents, .videos, .music, .archives, .software], id: \.self) { category in
                        SidebarRow(
                            category: category,
                            badge: 0,
                            isSelected: selectedCategory == category
                        )
                        .tag(category)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 300)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: { NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil) }) {
                        Image(systemName: "sidebar.left")
                    }
                }
            }
        } detail: {
            // Main Content Area
            VStack(spacing: 0) {
                // Modern Toolbar
                ModernToolbar(
                    showingNewDownload: $showingNewDownload,
                    showingBatchImport: $showingBatchImport,
                    showingSettings: $showingSettings
                )
                
                // Search Bar and View Toggle
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search downloads...", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    
                    // View Mode Toggle
                    Picker("View", selection: $viewMode) {
                        ForEach(ViewMode.allCases, id: \.self) { mode in
                            Image(systemName: mode.icon)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 80)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                // Download List (Card or List view)
                Group {
                    if viewMode == .card {
                        ModernDownloadListView(
                            filter: selectedCategory.filterKey,
                            searchText: searchText
                        )
                    } else {
                        ModernListView(
                            filter: selectedCategory.filterKey,
                            searchText: searchText
                        )
                    }
                }
                
                // Status Bar
                ModernStatusBar()
            }
            .background(VisualEffectBackground())
        }
        .sheet(isPresented: $showingNewDownload) {
            ModernNewDownloadSheet()
        }
        .sheet(isPresented: $showingBatchImport) {
            BatchImportSheet()
        }
        .sheet(isPresented: $showingSettings) {
            ModernSettingsView()
        }
        .sheet(isPresented: $showingBrowserDownload) {
            BrowserDownloadDialog(request: browserDownloadRequest)
        }
        .onOpenURL { url in
            handleIncomingURL(url)
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        // Activate app and bring existing window to front
        NSApp.activate(ignoringOtherApps: true)
        
        // Find and activate the main window
        if let mainWindow = NSApp.windows.first(where: { $0.isVisible }) {
            mainWindow.makeKeyAndOrderFront(nil)
        }
        
        // Parse swiftfetch://download?url=...&filename=...
        guard url.scheme == "swiftfetch",
              url.host == "download",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return
        }
        
        // Extract parameters
        let downloadURL = queryItems.first(where: { $0.name == "url" })?.value ?? ""
        let filename = queryItems.first(where: { $0.name == "filename" })?.value
        let referrer = queryItems.first(where: { $0.name == "referrer" })?.value
        let cookies = queryItems.first(where: { $0.name == "cookies" })?.value
        let userAgent = queryItems.first(where: { $0.name == "userAgent" })?.value
        
        print("Received download URL: \(downloadURL)")
        print("Filename: \(filename ?? "none")")
        
        // Create browser download request and show dialog
        guard let url = URL(string: downloadURL) else {
            print("Invalid URL: \(downloadURL)")
            return
        }
        
        var headers: [String: String] = [:]
        if let referrer = referrer {
            headers["Referer"] = referrer
        }
        if let cookies = cookies, !cookies.isEmpty {
            headers["Cookie"] = cookies
        }
        if let userAgent = userAgent {
            headers["User-Agent"] = userAgent
        }
        
        browserDownloadRequest = BrowserDownloadRequest(
            url: url.absoluteString,
            filename: filename,
            referrer: referrer,
            cookies: cookies,
            userAgent: userAgent,
            tabUrl: nil,
            tabTitle: nil
        )
        showingBrowserDownload = true
    }
}

struct SidebarRow: View {
    let category: ModernContentView.SidebarCategory
    let badge: Int
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Image(systemName: category.icon)
                .font(.system(size: 14))
                .foregroundColor(isSelected ? .white : .accentColor)
                .frame(width: 20)
            
            Text(category.rawValue)
                .font(.system(size: 13, weight: .medium))
            
            Spacer()
            
            if badge > 0 {
                Text("\(badge)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSelected ? .white : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.15))
                    )
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
    }
}

struct ModernToolbar: View {
    @EnvironmentObject var downloadManager: DownloadManager
    @Binding var showingNewDownload: Bool
    @Binding var showingBatchImport: Bool
    @Binding var showingSettings: Bool
    @State private var speedLimit: SpeedLimit = .unlimited
    
    enum SpeedLimit: String, CaseIterable {
        case unlimited = "Unlimited"
        case slow = "1 MB/s"
        case medium = "5 MB/s"
        case fast = "10 MB/s"
        
        var value: Int? {
            switch self {
            case .unlimited: return nil
            case .slow: return 1024
            case .medium: return 5120
            case .fast: return 10240
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Add Download
            Button(action: { showingNewDownload = true }) {
                Label("Add", systemImage: "plus.circle.fill")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(ModernButtonStyle())
            
            Button(action: { showingBatchImport = true }) {
                Label("Batch", systemImage: "square.and.arrow.down.on.square")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(ModernButtonStyle())
            
            Divider()
                .frame(height: 20)
            
            // Control Buttons
            Button(action: { Task { await downloadManager.startAll() } }) {
                Label("Start All", systemImage: "play.fill")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(ModernButtonStyle())
            .disabled(downloadManager.queuedTasks.isEmpty)
            
            Button(action: { Task { await downloadManager.pauseAll() } }) {
                Label("Pause All", systemImage: "pause.fill")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(ModernButtonStyle())
            .disabled(downloadManager.activeTasks.isEmpty)
            
            Divider()
                .frame(height: 20)
            
            // Speed Limit
            Picker("", selection: $speedLimit) {
                ForEach(SpeedLimit.allCases, id: \.self) { limit in
                    Text(limit.rawValue).tag(limit)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 110)
            .onChange(of: speedLimit) { _, newValue in
                if let value = newValue.value {
                    Task {
                        try await downloadManager.setGlobalSpeedLimit(value)
                    }
                }
            }
            
            Spacer()
            
            // Settings
            Button(action: { showingSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14))
            }
            .buttonStyle(ModernButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(VisualEffectBackground(material: .headerView))
    }
}

struct ModernButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? 
                          Color.accentColor.opacity(0.2) : 
                          Color.accentColor.opacity(0.1))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct ModernStatusBar: View {
    @EnvironmentObject var downloadManager: DownloadManager
    
    var body: some View {
        HStack(spacing: 16) {
            // Download Speed
            HStack(spacing: 4) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 11))
                    .foregroundColor(.green)
                Text(downloadManager.globalStats.formattedDownloadSpeed)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
            }
            
            Divider()
                .frame(height: 14)
            
            // Stats
            HStack(spacing: 12) {
                StatLabel(
                    icon: "bolt.fill",
                    value: "\(downloadManager.globalStats.numActive)",
                    color: .orange
                )
                
                StatLabel(
                    icon: "clock.fill",
                    value: "\(downloadManager.globalStats.numWaiting)",
                    color: .blue
                )
                
                StatLabel(
                    icon: "checkmark.circle.fill",
                    value: "\(downloadManager.completedTasks.count)",
                    color: .green
                )
            }
            
            Spacer()
            
            // Total Downloads
            Text("\(downloadManager.tasks.count) total")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(VisualEffectBackground(material: .menu))
    }
}

struct StatLabel: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 11, weight: .medium))
        }
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .sidebar
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}


struct BrowserDownloadDialog: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var downloadManager: DownloadManager
    let request: BrowserDownloadRequest?
    
    @State private var customFilename = ""
    @State private var selectedCategory = "General"
    @State private var destinationPath = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    @State private var rememberPath = false
    @State private var fileSize: String = ""
    
    let categories = ["General", "Documents", "Videos", "Music", "Archives", "Software"]
    
    var body: some View {
        VStack(spacing: 0) {
            if let request = request {
                // Header - similar to image design
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text("Download File")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Confirm download details")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if !fileSize.isEmpty {
                            VStack(alignment: .trailing) {
                                Text(fileSize)
                                    .font(.system(size: 16, weight: .medium))
                                Text("Size")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
                
                Divider()
                
                // Form content matching the design
                VStack(alignment: .leading, spacing: 20) {
                    // URL field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("URL")
                            .font(.system(size: 13, weight: .medium))
                        
                        Text(request.url)
                            .font(.system(size: 12, design: .monospaced))
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    
                    // Category picker
                    HStack {
                        Text("Category")
                            .font(.system(size: 13, weight: .medium))
                            .frame(width: 80, alignment: .leading)
                        
                        Picker("", selection: $selectedCategory) {
                            ForEach(categories, id: \.self) { category in
                                Text(category).tag(category)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)
                        
                        Button(action: { /* Add new category */ }) {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.borderless)
                    }
                    
                    // Save As field
                    HStack {
                        Text("Save As")
                            .font(.system(size: 13, weight: .medium))
                            .frame(width: 80, alignment: .leading)
                        
                        TextField(request.filename ?? "filename", text: $customFilename)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("...") {
                            // File browser button
                        }
                        .buttonStyle(.bordered)
                        .frame(width: 40)
                    }
                    
                    // Remember path checkbox
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: $rememberPath) {
                            Text("Remember this path for \"\(selectedCategory)\" category")
                                .font(.system(size: 12))
                        }
                        .toggleStyle(.checkbox)
                        
                        // Path display
                        Text(destinationPath.path)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                    }
                    
                    // Description field (empty in design)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description")
                            .font(.system(size: 13, weight: .medium))
                        
                        TextEditor(text: .constant(""))
                            .frame(height: 60)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                Spacer()
                
                Divider()
                
                // Action buttons
                HStack(spacing: 12) {
                    Button("Download Later") {
                        downloadLater()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Start Download") {
                        startDownload()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                }
                .padding(16)
            }
        }
        .frame(width: 500, height: 400)
        .background(VisualEffectBackground())
        .onAppear {
            if let request = request {
                customFilename = request.filename ?? URL(string: request.url)?.lastPathComponent ?? "download"
                loadFileSize()
            }
        }
    }
    
    private func loadFileSize() {
        guard let request = request,
              let url = URL(string: request.url) else { return }
        
        Task {
            do {
                var urlRequest = URLRequest(url: url)
                urlRequest.httpMethod = "HEAD"
                
                // Add headers from browser
                if let referrer = request.referrer {
                    urlRequest.setValue(referrer, forHTTPHeaderField: "Referer")
                }
                if let cookies = request.cookies {
                    urlRequest.setValue(cookies, forHTTPHeaderField: "Cookie")
                }
                if let userAgent = request.userAgent {
                    urlRequest.setValue(userAgent, forHTTPHeaderField: "User-Agent")
                }
                
                let (_, response) = try await URLSession.shared.data(for: urlRequest)
                
                if let httpResponse = response as? HTTPURLResponse,
                   let contentLength = httpResponse.value(forHTTPHeaderField: "Content-Length"),
                   let bytes = Int64(contentLength) {
                    
                    await MainActor.run {
                        fileSize = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
                    }
                }
            } catch {
                print("Failed to get file size: \(error)")
            }
        }
    }
    
    private func startDownload() {
        guard let request = request,
              let url = URL(string: request.url) else { return }
        
        Task {
            do {
                var headers: [String: String] = [:]
                if let referrer = request.referrer {
                    headers["Referer"] = referrer
                }
                if let cookies = request.cookies {
                    headers["Cookie"] = cookies
                }
                if let userAgent = request.userAgent {
                    headers["User-Agent"] = userAgent
                }
                
                let options = DownloadOptions(
                    destination: destinationPath,
                    filename: customFilename.isEmpty ? nil : customFilename,
                    segments: 4,
                    headers: headers
                )
                
                _ = try await downloadManager.addDownload(url: url, options: options)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Failed to start download: \(error)")
            }
        }
    }
    
    private func downloadLater() {
        guard let request = request,
              let url = URL(string: request.url) else { return }
        
        Task {
            do {
                var headers: [String: String] = [:]
                if let referrer = request.referrer {
                    headers["Referer"] = referrer
                }
                if let cookies = request.cookies {
                    headers["Cookie"] = cookies
                }
                if let userAgent = request.userAgent {
                    headers["User-Agent"] = userAgent
                }
                
                let options = DownloadOptions(
                    destination: destinationPath,
                    filename: customFilename.isEmpty ? nil : customFilename,
                    segments: 4,
                    headers: headers
                )
                
                let task = try await downloadManager.addDownload(url: url, options: options)
                
                // Immediately pause the download so it's queued for later
                try await downloadManager.pauseDownload(taskId: task.id)
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Failed to add download: \(error)")
            }
        }
    }
}