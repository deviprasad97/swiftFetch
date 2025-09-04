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
            
            // Production Extension ID Configuration
            GroupBox("Production Extension ID") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(.orange)
                        Text("Chrome Web Store Extension ID")
                            .fontWeight(.medium)
                        Spacer()
                    }
                    
                    Text("After publishing to Chrome Web Store, configure the assigned extension ID here.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Production ID:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(BrowserIntegrationManager.shared.getProductionExtensionID() ?? "mdllhgebmaocbeagkopjjmcabalbiikh")
                                .font(.system(.caption, design: .monospaced))
                                .padding(6)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(4)
                        }
                        
                        Spacer()
                        
                        Button("Configure ID...") {
                            configureExtensionID()
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
    
    private func configureExtensionID() {
        let alert = NSAlert()
        alert.messageText = "Configure Chrome Web Store Extension ID"
        alert.informativeText = """
        After publishing your extension to the Chrome Web Store, Google assigns a unique extension ID. 
        
        To find your extension ID:
        1. Go to Chrome Web Store Developer Dashboard
        2. Select your published extension
        3. Copy the extension ID from the URL or dashboard
        
        Enter the new extension ID below:
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Update")
        alert.addButton(withTitle: "Cancel")
        
        // Add text field for extension ID input
        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        inputField.placeholderString = "Enter Chrome Web Store extension ID..."
        inputField.stringValue = BrowserIntegrationManager.shared.getProductionExtensionID() ?? ""
        alert.accessoryView = inputField
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            let newExtensionID = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !newExtensionID.isEmpty && newExtensionID.count == 32 {
                // Configure the new extension ID
                BrowserIntegrationManager.shared.configureProductionExtensionID(newExtensionID)
                
                // Refresh the integration status
                integrationStatus = BrowserIntegrationManager.shared.checkIntegrationStatus()
                
                // Show success message
                let successAlert = NSAlert()
                successAlert.messageText = "Extension ID Updated"
                successAlert.informativeText = "The production extension ID has been updated successfully. Native host manifests have been reinstalled with the new ID."
                successAlert.alertStyle = .informational
                successAlert.addButton(withTitle: "OK")
                successAlert.runModal()
            } else {
                // Show error for invalid extension ID
                let errorAlert = NSAlert()
                errorAlert.messageText = "Invalid Extension ID"
                errorAlert.informativeText = "Extension IDs must be exactly 32 characters long. Please check your Chrome Web Store dashboard for the correct ID."
                errorAlert.alertStyle = .warning
                errorAlert.addButton(withTitle: "OK")
                errorAlert.runModal()
            }
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