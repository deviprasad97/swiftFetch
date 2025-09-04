import SwiftUI

struct NewDownloadSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var downloadManager: DownloadManager
    
    @State private var urlText = ""
    @State private var filename = ""
    @State private var destination = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    @State private var selectedCategory: Category?
    @State private var segments = 8
    @State private var speedLimit: Int?
    @State private var useAuthentication = false
    @State private var username = ""
    @State private var password = ""
    @State private var useProxy = false
    @State private var proxyURL = ""
    @State private var scheduleDownload = false
    @State private var scheduleDate = Date()
    @State private var verifyChecksum = false
    @State private var checksumType = ChecksumType.sha256
    @State private var checksumValue = ""
    
    @State private var showAdvancedOptions = false
    @State private var isValidating = false
    @State private var validationError: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("New Download")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if let error = validationError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding()
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // URL Input
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("URL", systemImage: "link")
                                .font(.headline)
                            
                            TextField("https://example.com/file.zip", text: $urlText)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    validateURL()
                                }
                            
                            if !urlText.isEmpty {
                                HStack {
                                    Image(systemName: isValidURL ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(isValidURL ? .green : .red)
                                    Text(isValidURL ? "Valid URL" : "Invalid URL")
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    
                    // File Options
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("File Options", systemImage: "doc")
                                .font(.headline)
                            
                            HStack {
                                Text("Filename:")
                                TextField("Leave empty for automatic", text: $filename)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            HStack {
                                Text("Save to:")
                                Text(destination.lastPathComponent)
                                    .foregroundColor(.secondary)
                                    .truncationMode(.middle)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Button("Choose...") {
                                    chooseDestination()
                                }
                            }
                            
                            HStack {
                                Text("Category:")
                                Picker("", selection: $selectedCategory) {
                                    Text("None").tag(nil as Category?)
                                    Text("Documents").tag(Category(id: 1, name: "Documents", destination: destination))
                                    Text("Videos").tag(Category(id: 2, name: "Videos", destination: destination))
                                    Text("Music").tag(Category(id: 3, name: "Music", destination: destination))
                                    Text("Archives").tag(Category(id: 4, name: "Archives", destination: destination))
                                    Text("Software").tag(Category(id: 5, name: "Software", destination: destination))
                                }
                                .pickerStyle(.menu)
                            }
                        }
                    }
                    
                    // Download Settings
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Download Settings", systemImage: "gearshape")
                                .font(.headline)
                            
                            HStack {
                                Text("Segments:")
                                Slider(value: Binding(
                                    get: { Double(segments) },
                                    set: { segments = Int($0) }
                                ), in: 1...16, step: 1)
                                Text("\(segments)")
                                    .monospacedDigit()
                                    .frame(width: 30)
                            }
                            
                            HStack {
                                Toggle("Speed Limit:", isOn: Binding(
                                    get: { speedLimit != nil },
                                    set: { enabled in
                                        speedLimit = enabled ? 1024 : nil
                                    }
                                ))
                                
                                if speedLimit != nil {
                                    TextField("KB/s", value: $speedLimit, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 100)
                                    Text("KB/s")
                                }
                            }
                            
                            Toggle("Schedule Download", isOn: $scheduleDownload)
                            
                            if scheduleDownload {
                                DatePicker("Start at:", selection: $scheduleDate, displayedComponents: [.date, .hourAndMinute])
                            }
                        }
                    }
                    
                    // Advanced Options
                    DisclosureGroup("Advanced Options", isExpanded: $showAdvancedOptions) {
                        VStack(alignment: .leading, spacing: 16) {
                            // Authentication
                            GroupBox {
                                VStack(alignment: .leading, spacing: 8) {
                                    Toggle("Use Authentication", isOn: $useAuthentication)
                                    
                                    if useAuthentication {
                                        HStack {
                                            Text("Username:")
                                            TextField("", text: $username)
                                                .textFieldStyle(.roundedBorder)
                                        }
                                        
                                        HStack {
                                            Text("Password:")
                                            SecureField("", text: $password)
                                                .textFieldStyle(.roundedBorder)
                                        }
                                    }
                                }
                            }
                            
                            // Proxy
                            GroupBox {
                                VStack(alignment: .leading, spacing: 8) {
                                    Toggle("Use Proxy", isOn: $useProxy)
                                    
                                    if useProxy {
                                        HStack {
                                            Text("Proxy URL:")
                                            TextField("http://proxy:8080", text: $proxyURL)
                                                .textFieldStyle(.roundedBorder)
                                        }
                                    }
                                }
                            }
                            
                            // Checksum
                            GroupBox {
                                VStack(alignment: .leading, spacing: 8) {
                                    Toggle("Verify Checksum", isOn: $verifyChecksum)
                                    
                                    if verifyChecksum {
                                        HStack {
                                            Text("Type:")
                                            Picker("", selection: $checksumType) {
                                                Text("MD5").tag(ChecksumType.md5)
                                                Text("SHA-1").tag(ChecksumType.sha1)
                                                Text("SHA-256").tag(ChecksumType.sha256)
                                                Text("SHA-512").tag(ChecksumType.sha512)
                                            }
                                            .pickerStyle(.segmented)
                                        }
                                        
                                        HStack {
                                            Text("Value:")
                                            TextField("", text: $checksumValue)
                                                .textFieldStyle(.roundedBorder)
                                                .font(.system(.caption, design: .monospaced))
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top)
                }
                .padding()
            }
            
            Divider()
            
            // Footer buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Paste from Clipboard") {
                    if let clipboard = NSPasteboard.general.string(forType: .string) {
                        urlText = clipboard
                        validateURL()
                    }
                }
                
                Button("Add Download") {
                    addDownload()
                }
                .keyboardShortcut(.return)
                .disabled(urlText.isEmpty || !isValidURL)
            }
            .padding()
        }
        .frame(width: 600, height: 700)
        .onAppear {
            // Auto-paste if clipboard contains URL
            if let clipboard = NSPasteboard.general.string(forType: .string),
               clipboard.hasPrefix("http") {
                urlText = clipboard
                validateURL()
            }
        }
    }
    
    var isValidURL: Bool {
        guard !urlText.isEmpty else { return false }
        return URL(string: urlText) != nil
    }
    
    func validateURL() {
        validationError = nil
        
        guard !urlText.isEmpty else {
            validationError = "Please enter a URL"
            return
        }
        
        guard URL(string: urlText) != nil else {
            validationError = "Invalid URL format"
            return
        }
        
        // Extract filename from URL if not provided
        if filename.isEmpty, let url = URL(string: urlText) {
            filename = url.lastPathComponent
        }
    }
    
    func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = destination
        
        if panel.runModal() == .OK {
            destination = panel.url ?? destination
        }
    }
    
    func addDownload() {
        guard let url = URL(string: urlText) else { return }
        
        Task {
            var options = DownloadOptions(
                destination: destination,
                filename: filename.isEmpty ? nil : filename,
                segments: segments,
                speedLimit: speedLimit,
                category: selectedCategory
            )
            
            if verifyChecksum {
                options.checksum = Checksum(type: checksumType, value: checksumValue)
            }
            
            if useAuthentication {
                options.headers["Authorization"] = "Basic \(Data("\(username):\(password)".utf8).base64EncodedString())"
            }
            
            if scheduleDownload {
                options.schedule = DownloadSchedule(date: scheduleDate)
            }
            
            do {
                _ = try await downloadManager.addDownload(url: url, options: options)
                dismiss()
            } catch {
                validationError = error.localizedDescription
            }
        }
    }
}

#Preview {
    NewDownloadSheet()
        .environmentObject(DownloadManager())
}