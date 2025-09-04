import SwiftUI

struct ModernNewDownloadSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var downloadManager: DownloadManager
    @State private var urlText = ""
    @State private var customFilename = ""
    @State private var destinationPath = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    @State private var segments = 8
    @State private var startImmediately = true
    @State private var isValidURL = false
    @State private var errorMessage = ""
    @FocusState private var isURLFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.accentColor)
                    
                    VStack(alignment: .leading) {
                        Text("New Download")
                            .font(.system(size: 20, weight: .semibold))
                        Text("Enter a URL to start downloading")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                
                Divider()
            }
            
            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // URL Input
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Download URL", systemImage: "link")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        HStack {
                            TextField("https://example.com/file.zip", text: $urlText)
                                .textFieldStyle(.plain)
                                .focused($isURLFieldFocused)
                                .onSubmit {
                                    validateURL()
                                }
                                .onChange(of: urlText) { _, _ in
                                    validateURL()
                                }
                            
                            if !urlText.isEmpty {
                                Image(systemName: isValidURL ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(isValidURL ? .green : .red)
                                    .font(.system(size: 14))
                            }
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isURLFieldFocused ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                        
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.system(size: 11))
                                .foregroundColor(.red)
                        }
                    }
                    
                    // Filename
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Save As", systemImage: "doc")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        TextField("Leave empty to use original filename", text: $customFilename)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    // Destination
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Save To", systemImage: "folder")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.accentColor)
                            
                            Text(destinationPath.lastPathComponent)
                                .lineLimit(1)
                            
                            Text(destinationPath.path)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            Spacer()
                            
                            Button("Choose...") {
                                chooseDestination()
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(NSColor.controlBackgroundColor))
                        )
                    }
                    
                    // Options
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Options")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Label("Segments", systemImage: "square.grid.2x2")
                                .font(.system(size: 13))
                            
                            Stepper(value: $segments, in: 1...32) {
                                Text("\(segments)")
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .frame(width: 30)
                            }
                        }
                        
                        Toggle(isOn: $startImmediately) {
                            Label("Start Download Immediately", systemImage: "play.fill")
                                .font(.system(size: 13))
                        }
                        .toggleStyle(.checkbox)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(NSColor.controlBackgroundColor))
                    )
                }
                .padding(24)
            }
            
            Divider()
            
            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Add Download") {
                    addDownload()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValidURL)
                .buttonStyle(.borderedProminent)
            }
            .padding(20)
        }
        .frame(width: 550, height: 500)
        .background(VisualEffectBackground())
        .onAppear {
            isURLFieldFocused = true
            checkClipboard()
        }
    }
    
    func validateURL() {
        if urlText.isEmpty {
            isValidURL = false
            errorMessage = ""
            return
        }
        
        if let url = URL(string: urlText),
           let scheme = url.scheme,
           ["http", "https", "ftp", "ftps", "magnet"].contains(scheme.lowercased()) {
            isValidURL = true
            errorMessage = ""
        } else {
            isValidURL = false
            errorMessage = "Please enter a valid URL"
        }
    }
    
    func checkClipboard() {
        if let string = NSPasteboard.general.string(forType: .string),
           let url = URL(string: string),
           let scheme = url.scheme,
           ["http", "https", "ftp", "ftps"].contains(scheme.lowercased()) {
            urlText = string
            validateURL()
        }
    }
    
    func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.directoryURL = destinationPath
        
        if panel.runModal() == .OK, let url = panel.url {
            destinationPath = url
        }
    }
    
    func addDownload() {
        guard let url = URL(string: urlText) else { return }
        
        Task {
            do {
                let options = DownloadOptions(
                    destination: destinationPath,
                    filename: customFilename.isEmpty ? nil : customFilename,
                    segments: segments
                )
                
                _ = try await downloadManager.addDownload(url: url, options: options)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}