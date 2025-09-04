import SwiftUI

struct ContentView: View {
    @EnvironmentObject var downloadManager: DownloadManager
    @State private var selectedCategory: String? = "all"
    @State private var searchText = ""
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(selection: $selectedCategory) {
                Section("Downloads") {
                    NavigationLink(tag: "all", selection: $selectedCategory) {
                        // This is the destination, handled by the detail view
                        EmptyView()
                    } label: {
                        Label("All Downloads", systemImage: "arrow.down.circle")
                            .badge(downloadManager.tasks.count)
                    }
                    
                    NavigationLink(tag: "active", selection: $selectedCategory) {
                        EmptyView()
                    } label: {
                        Label("Active", systemImage: "bolt.circle.fill")
                            .badge(downloadManager.activeTasks.count)
                    }
                    
                    NavigationLink(tag: "queued", selection: $selectedCategory) {
                        EmptyView()
                    } label: {
                        Label("Queued", systemImage: "clock")
                            .badge(downloadManager.queuedTasks.count)
                    }
                    
                    NavigationLink(tag: "completed", selection: $selectedCategory) {
                        EmptyView()
                    } label: {
                        Label("Completed", systemImage: "checkmark.circle.fill")
                            .badge(downloadManager.completedTasks.count)
                    }
                
                }
                
                Section("Categories") {
                    NavigationLink(tag: "category.documents", selection: $selectedCategory) {
                        EmptyView()
                    } label: {
                        Label("Documents", systemImage: "doc.fill")
                    }
                    
                    NavigationLink(tag: "category.videos", selection: $selectedCategory) {
                        EmptyView()
                    } label: {
                        Label("Videos", systemImage: "video.fill")
                    }
                    
                    NavigationLink(tag: "category.music", selection: $selectedCategory) {
                        EmptyView()
                    } label: {
                        Label("Music", systemImage: "music.note")
                    }
                    
                    NavigationLink(tag: "category.archives", selection: $selectedCategory) {
                        EmptyView()
                    } label: {
                        Label("Archives", systemImage: "archivebox.fill")
                    }
                    
                    NavigationLink(tag: "category.software", selection: $selectedCategory) {
                        EmptyView()
                    } label: {
                        Label("Software", systemImage: "app.fill")
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 250)
            .listStyle(.sidebar)
        } detail: {
            // Main content area
            VStack(spacing: 0) {
                // Toolbar
                DownloadToolbar()
                
                // Download list
                DownloadListView(filter: selectedCategory ?? "all", searchText: searchText)
                    .searchable(text: $searchText, prompt: "Search downloads...")
                
                // Status bar
                StatusBar()
            }
        }
        .sheet(isPresented: $downloadManager.showNewDownloadSheet) {
            NewDownloadSheet()
        }
        .sheet(isPresented: $downloadManager.showBatchImport) {
            BatchImportSheet()
        }
        .sheet(isPresented: $downloadManager.showSettings) {
            SettingsView()
        }
    }
}

struct DownloadToolbar: View {
    @EnvironmentObject var downloadManager: DownloadManager
    @State private var selectedSpeedLimit: Int? = nil
    
    var body: some View {
        HStack {
            Button(action: { downloadManager.showNewDownloadSheet = true }) {
                Label("Add", systemImage: "plus")
            }
            
            Divider()
                .frame(height: 20)
            
            Button(action: { Task { await downloadManager.startAll() } }) {
                Label("Start All", systemImage: "play.fill")
            }
            .disabled(downloadManager.queuedTasks.isEmpty)
            
            Button(action: { Task { await downloadManager.pauseAll() } }) {
                Label("Pause All", systemImage: "pause.fill")
            }
            .disabled(downloadManager.activeTasks.isEmpty)
            
            Divider()
                .frame(height: 20)
            
            Picker("Speed Limit", selection: $selectedSpeedLimit) {
                Text("Unlimited").tag(nil as Int?)
                Text("1 MB/s").tag(1024)
                Text("5 MB/s").tag(5120)
                Text("10 MB/s").tag(10240)
                Text("Custom...").tag(-1)
            }
            .pickerStyle(.menu)
            .frame(width: 120)
            .onChange(of: selectedSpeedLimit) { _, newValue in
                if let limit = newValue, limit != -1 {
                    Task {
                        try await downloadManager.setGlobalSpeedLimit(limit)
                    }
                }
            }
            
            Spacer()
            
            Button(action: { downloadManager.showSettings = true }) {
                Label("Settings", systemImage: "gear")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct StatusBar: View {
    @EnvironmentObject var downloadManager: DownloadManager
    
    var body: some View {
        HStack {
            Image(systemName: "arrow.down")
                .foregroundColor(.green)
            Text(downloadManager.globalStats.formattedDownloadSpeed)
                .monospacedDigit()
            
            Divider()
                .frame(height: 16)
            
            Text("Active: \(downloadManager.globalStats.numActive)")
            Text("Waiting: \(downloadManager.globalStats.numWaiting)")
            
            Spacer()
            
            if downloadManager.globalStats.numActive > 0 {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.7)
            }
            
            Text("\(downloadManager.tasks.count) total downloads")
                .foregroundColor(.secondary)
        }
        .font(.caption)
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct BatchImportSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var downloadManager: DownloadManager
    @State private var urlText = ""
    @State private var destination = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Batch Import")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Enter URLs (one per line)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            TextEditor(text: $urlText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 200)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
            
            HStack {
                Text("Destination:")
                Text(destination.lastPathComponent)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Choose...") {
                    chooseDestination()
                }
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Import") {
                    importURLs()
                }
                .keyboardShortcut(.return)
                .disabled(urlText.isEmpty)
            }
        }
        .padding()
        .frame(width: 500, height: 400)
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
    
    func importURLs() {
        let urls = urlText.split(separator: "\n")
            .compactMap { line -> URL? in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                return URL(string: trimmed)
            }
        
        Task {
            for url in urls {
                try await downloadManager.addDownload(
                    url: url,
                    options: DownloadOptions(destination: destination)
                )
            }
            dismiss()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DownloadManager())
}