import SwiftUI

struct ModernDownloadRow: View {
    let task: DownloadTask
    @EnvironmentObject var downloadManager: DownloadManager
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 16) {
            // File Type Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconBackgroundColor)
                    .frame(width: 40, height: 40)
                
                Image(systemName: fileIcon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
            }
            
            // File Info
            VStack(alignment: .leading, spacing: 6) {
                Text(task.filename)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                
                HStack(spacing: 12) {
                    // File size
                    Text(formatFileSize)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    // Status
                    StatusBadge(status: task.status)
                    
                    // Speed (if downloading)
                    if task.status == .active && task.downloadSpeed > 0 {
                        Text(formatSpeed(task.downloadSpeed))
                            .font(.system(size: 11))
                            .foregroundColor(.green)
                    }
                    
                    // ETA (if available)
                    if let eta = task.eta, task.status == .active {
                        Text(formatETA(eta))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Progress Bar
                if task.status == .active || task.status == .paused {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(NSColor.separatorColor).opacity(0.3))
                                .frame(height: 4)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(progressColor)
                                .frame(width: geometry.size.width * task.progress, height: 4)
                        }
                    }
                    .frame(height: 4)
                }
            }
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 8) {
                switch task.status {
                case .active:
                    ActionButton(icon: "pause.fill", action: pauseDownload)
                        .help("Pause")
                    
                case .paused, .pending, .waiting:
                    ActionButton(icon: "play.fill", action: resumeDownload)
                        .help("Resume")
                    
                case .completed:
                    ActionButton(icon: "folder", action: openInFinder)
                        .help("Show in Finder")
                    
                default:
                    EmptyView()
                }
                
                ActionButton(icon: "xmark", action: removeDownload)
                    .help("Remove")
            }
            .opacity(isHovering ? 1 : 0.3)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(backgroundColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
    
    // MARK: - Computed Properties
    
    var fileIcon: String {
        let ext = task.url.pathExtension.lowercased()
        switch ext {
        case "mp4", "avi", "mkv", "mov": return "video.fill"
        case "mp3", "aac", "flac", "wav": return "music.note"
        case "zip", "rar", "7z", "tar", "gz": return "archivebox.fill"
        case "pdf": return "doc.richtext.fill"
        case "dmg", "pkg", "app": return "app.badge"
        case "iso": return "opticaldisc.fill"
        case "jpg", "jpeg", "png", "gif": return "photo.fill"
        default: return "doc.fill"
        }
    }
    
    var iconColor: Color {
        switch task.status {
        case .active: return .blue
        case .completed: return .green
        case .error: return .red
        case .paused: return .orange
        default: return .secondary
        }
    }
    
    var iconBackgroundColor: Color {
        iconColor.opacity(0.15)
    }
    
    var backgroundColor: Color {
        if isHovering {
            return Color(NSColor.controlBackgroundColor)
        }
        return Color.clear
    }
    
    var borderColor: Color {
        if isHovering {
            return Color(NSColor.separatorColor)
        }
        return Color.clear
    }
    
    var progressColor: Color {
        switch task.status {
        case .active: return .blue
        case .paused: return .orange
        case .error: return .red
        default: return .gray
        }
    }
    
    var formatFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        
        if let totalSize = task.size {
            let completed = formatter.string(fromByteCount: task.completedSize)
            let total = formatter.string(fromByteCount: totalSize)
            return "\(completed) / \(total)"
        } else {
            return formatter.string(fromByteCount: task.completedSize)
        }
    }
    
    // MARK: - Helper Functions
    
    func formatSpeed(_ bytesPerSecond: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytesPerSecond) + "/s"
    }
    
    func formatETA(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return "ETA: " + (formatter.string(from: seconds) ?? "Unknown")
    }
    
    // MARK: - Actions
    
    func pauseDownload() {
        Task {
            try? await downloadManager.pauseDownload(taskId: task.id)
        }
    }
    
    func resumeDownload() {
        Task {
            try? await downloadManager.resumeDownload(taskId: task.id)
        }
    }
    
    func removeDownload() {
        Task {
            await downloadManager.removeDownload(taskId: task.id)
        }
    }
    
    func openInFinder() {
        NSWorkspace.shared.selectFile(
            task.destination.appendingPathComponent(task.filename).path,
            inFileViewerRootedAtPath: task.destination.path
        )
    }
}

struct ActionButton: View {
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundColor(.primary)
    }
}

struct StatusBadge: View {
    let status: TaskStatus
    
    var text: String {
        switch status {
        case .active: return "Downloading"
        case .waiting: return "Waiting"
        case .paused: return "Paused"
        case .completed, .complete: return "Completed"
        case .error: return "Error"
        case .pending: return "Pending"
        case .removed: return "Removed"
        }
    }
    
    var color: Color {
        switch status {
        case .active: return .blue
        case .completed, .complete: return .green
        case .error: return .red
        case .paused: return .orange
        case .waiting, .pending: return .gray
        case .removed: return .secondary
        }
    }
    
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}