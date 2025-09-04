import SwiftUI

struct SimpleSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("maxConcurrentDownloads") private var maxConcurrentDownloads = 5
    @AppStorage("defaultSegments") private var defaultSegments = 8
    @AppStorage("globalSpeedLimit") private var globalSpeedLimit = 0
    @AppStorage("defaultDownloadPath") private var defaultDownloadPath = ""
    @State private var selectedPath = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            // Settings Content
            Form {
                Section("Downloads") {
                    HStack {
                        Text("Download Location:")
                        Spacer()
                        Text(selectedPath.lastPathComponent)
                            .foregroundColor(.secondary)
                        Button("Change...") {
                            selectDownloadPath()
                        }
                    }
                    
                    HStack {
                        Text("Concurrent Downloads:")
                        Spacer()
                        Picker("", selection: $maxConcurrentDownloads) {
                            ForEach(1...10, id: \.self) { num in
                                Text("\(num)").tag(num)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 80)
                    }
                    
                    HStack {
                        Text("Segments per Download:")
                        Spacer()
                        Picker("", selection: $defaultSegments) {
                            ForEach([1, 2, 4, 8, 16], id: \.self) { num in
                                Text("\(num)").tag(num)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 80)
                    }
                }
                
                Section("Network") {
                    HStack {
                        Text("Speed Limit:")
                        Spacer()
                        if globalSpeedLimit == 0 {
                            Text("Unlimited")
                                .foregroundColor(.secondary)
                        } else {
                            Text("\(globalSpeedLimit) KB/s")
                                .foregroundColor(.secondary)
                        }
                        Picker("", selection: $globalSpeedLimit) {
                            Text("Unlimited").tag(0)
                            Text("256 KB/s").tag(256)
                            Text("512 KB/s").tag(512)
                            Text("1 MB/s").tag(1024)
                            Text("5 MB/s").tag(5120)
                            Text("10 MB/s").tag(10240)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                    }
                }
            }
            .formStyle(.grouped)
            .padding()
        }
        .frame(width: 500, height: 400)
    }
    
    func selectDownloadPath() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                selectedPath = url
                defaultDownloadPath = url.path
            }
        }
    }
}

#Preview {
    SimpleSettingsView()
}