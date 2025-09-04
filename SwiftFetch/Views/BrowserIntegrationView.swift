import SwiftUI

struct BrowserIntegrationView: View {
    @State private var integrationStatus = BrowserIntegrationManager.shared.checkIntegrationStatus()
    @State private var showingInstructions = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Image(systemName: "globe")
                    .font(.largeTitle)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading) {
                    Text("Browser Integration")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Connect SwiftFetch with your browser")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.bottom)
            
            // Status Section
            GroupBox("Integration Status") {
                VStack(spacing: 12) {
                    BrowserIntegrationStatusRow(
                        browser: "Chrome",
                        icon: "🌐",
                        isInstalled: integrationStatus.chromeInstalled
                    )
                    
                    BrowserIntegrationStatusRow(
                        browser: "Microsoft Edge",
                        icon: "🔷",
                        isInstalled: integrationStatus.edgeInstalled
                    )
                    
                    BrowserIntegrationStatusRow(
                        browser: "Brave",
                        icon: "🦁",
                        isInstalled: integrationStatus.braveInstalled
                    )
                    
                    BrowserIntegrationStatusRow(
                        browser: "Firefox",
                        icon: "🦊",
                        isInstalled: integrationStatus.firefoxInstalled
                    )
                }
                .padding(.vertical, 8)
            }
            
            // Extension Section
            GroupBox("Browser Extension") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "puzzlepiece.extension.fill")
                            .foregroundColor(.blue)
                        Text("SwiftFetch Extension")
                            .fontWeight(.medium)
                        Spacer()
                        
                        if integrationStatus.isAnyBrowserSetup {
                            Label("Ready", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        } else {
                            Label("Not Installed", systemImage: "xmark.circle")
                                .foregroundColor(.orange)
                                .font(.caption)
                        }
                    }
                    
                    Text("The extension enables right-click downloads and automatic capture of large files.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Button("Install Extension") {
                            installExtension()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Setup Instructions") {
                            showingInstructions = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.vertical, 8)
            }
            
            // Actions
            HStack {
                Button("Refresh Status") {
                    integrationStatus = BrowserIntegrationManager.shared.checkIntegrationStatus()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Reinstall Native Host") {
                    BrowserIntegrationManager.shared.setupBrowserIntegration()
                    integrationStatus = BrowserIntegrationManager.shared.checkIntegrationStatus()
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingInstructions) {
            InstructionsView()
        }
    }
    
    private func installExtension() {
        // For local testing, open the Extensions folder
        // Use the extension bundled with the app
        let extensionPath = Bundle.main.bundlePath + "/Contents/Resources/Chrome Extension"
        if FileManager.default.fileExists(atPath: extensionPath) {
            // Open Chrome extensions page with instructions
            NSWorkspace.shared.open(URL(string: "chrome://extensions")!)
            
            // Also open the folder in Finder
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: extensionPath)
            
            // Show alert with instructions
            let alert = NSAlert()
            alert.messageText = "Install SwiftFetch Extension"
            alert.informativeText = """
            To install the extension for testing:
            
            1. Chrome extensions page opened (chrome://extensions)
            2. Enable 'Developer mode' (top right)
            3. Click 'Load unpacked'
            4. Select the folder that opened in Finder
            5. The extension will be installed
            
            Extension ID: mdllhgebmaocbeagkopjjmcabalbiikh
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Got it")
            alert.runModal()
        } else {
            // Production: Open Chrome Web Store
            BrowserIntegrationManager.shared.openExtensionInstallPage()
        }
    }
}

struct BrowserIntegrationStatusRow: View {
    let browser: String
    let icon: String
    let isInstalled: Bool
    
    var body: some View {
        HStack {
            Text(icon)
                .font(.title3)
            
            Text(browser)
                .font(.system(.body, design: .rounded))
            
            Spacer()
            
            if isInstalled {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "minus.circle")
                    .foregroundColor(.gray)
            }
        }
    }
}

struct InstructionsView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Setup Instructions")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 16) {
                InstructionStep(
                    number: 1,
                    title: "Install Extension",
                    description: "Click 'Install Extension' to open the Chrome Web Store page"
                )
                
                InstructionStep(
                    number: 2,
                    title: "Add to Chrome",
                    description: "Click 'Add to Chrome' on the Web Store page"
                )
                
                InstructionStep(
                    number: 3,
                    title: "Grant Permissions",
                    description: "Accept the permissions when prompted"
                )
                
                InstructionStep(
                    number: 4,
                    title: "Start Using",
                    description: "Right-click any download link and select 'Download with SwiftFetch'"
                )
            }
            
            Text("Features")
                .font(.headline)
                .padding(.top)
            
            VStack(alignment: .leading, spacing: 8) {
                Label("Auto-capture downloads over 10MB", systemImage: "arrow.down.circle")
                Label("Right-click context menu integration", systemImage: "contextualmenu.and.cursorarrow")
                Label("Batch download all links on a page", systemImage: "square.stack.3d.down.right")
                Label("Video detection on supported sites", systemImage: "play.rectangle")
            }
            .font(.subheadline)
            
            Spacer()
            
            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 450, height: 500)
    }
}

struct InstructionStep: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.blue))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    BrowserIntegrationView()
}