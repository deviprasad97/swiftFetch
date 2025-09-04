import SwiftUI
import AppKit

struct ModernListView: View {
    @EnvironmentObject var downloadManager: DownloadManager
    let filter: String
    let searchText: String
    @State private var sortOrder = [KeyPathComparator(\DownloadTask.createdAt, order: .reverse)]
    @State private var selection = Set<String>()
    
    var filteredTasks: [DownloadTask] {
        var tasks = downloadManager.tasks
        
        // Apply filter
        switch filter {
        case "active":
            tasks = downloadManager.activeTasks
        case "queued":
            tasks = downloadManager.queuedTasks
        case "completed":
            tasks = downloadManager.completedTasks
        case let category where category.starts(with: "category."):
            let categoryName = String(category.dropFirst(9))
            tasks = filterByFileType(tasks, category: categoryName)
        default:
            break
        }
        
        // Apply search
        if !searchText.isEmpty {
            tasks = tasks.filter { task in
                task.filename.localizedCaseInsensitiveContains(searchText) ||
                task.url.absoluteString.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return tasks.sorted(using: sortOrder)
    }
    
    private func filterByFileType(_ tasks: [DownloadTask], category: String) -> [DownloadTask] {
        tasks.filter { task in
            let ext = task.url.pathExtension.lowercased()
            switch category {
            case "documents":
                return ["pdf", "doc", "docx", "txt", "rtf", "odt"].contains(ext)
            case "videos":
                return ["mp4", "avi", "mkv", "mov", "wmv", "flv", "webm"].contains(ext)
            case "music":
                return ["mp3", "aac", "flac", "wav", "m4a", "ogg", "wma"].contains(ext)
            case "archives":
                return ["zip", "rar", "7z", "tar", "gz", "bz2", "xz"].contains(ext)
            case "software":
                return ["dmg", "pkg", "app", "exe", "msi", "deb", "rpm"].contains(ext)
            default:
                return false
            }
        }
    }
    
    var body: some View {
        Table(filteredTasks, selection: $selection, sortOrder: $sortOrder) {
            // File Name Column
            TableColumn("File Name", value: \.filename) { task in
                HStack(spacing: 8) {
                    Image(systemName: iconForTask(task))
                        .font(.system(size: 14))
                        .foregroundColor(colorForStatus(task.status))
                    
                    Text(task.filename)
                        .lineLimit(1)
                        .help(task.filename)
                }
            }
            .width(min: 200, ideal: 300)
            
            // Size Column
            TableColumn("Size") { task in
                Text(formatBytes(task.size ?? 0))
                    .monospacedDigit()
            }
            .width(80)
            
            // Status Column
            TableColumn("Status", value: \.status.rawValue) { task in
                HStack(spacing: 4) {
                    Circle()
                        .fill(colorForStatus(task.status))
                        .frame(width: 8, height: 8)
                    
                    Text(task.status.displayName)
                        .font(.system(size: 12))
                    
                    if task.status == .active {
                        Text("(\(Int(task.progress * 100))%)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .width(120)
            
            // Progress Column
            TableColumn("Progress") { task in
                ProgressView(value: task.progress)
                    .progressViewStyle(.linear)
                    .frame(height: 4)
            }
            .width(min: 100, ideal: 150)
            
            // Time Left Column
            TableColumn("Time Left") { task in
                if task.status == .active, let eta = task.eta {
                    Text(formatTimeInterval(eta))
                        .font(.system(size: 12))
                        .monospacedDigit()
                } else {
                    Text("—")
                        .foregroundColor(.secondary)
                }
            }
            .width(80)
            
            // Transfer Rate Column
            TableColumn("Transfer Rate") { task in
                if task.status == .active {
                    Text(formatBytes(task.downloadSpeed) + "/s")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                        .monospacedDigit()
                } else {
                    Text("—")
                        .foregroundColor(.secondary)
                }
            }
            .width(100)
            
            // Last Try Date Column
            TableColumn("Last Try") { task in
                let date = task.startedAt ?? task.createdAt
                Text(date, style: .relative)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .width(100)
            
            // Description/URL Column
            TableColumn("URL") { task in
                Text(task.url.host ?? task.url.absoluteString)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .help(task.url.absoluteString)
            }
            .width(min: 150, ideal: 200)
        }
        .contextMenu(forSelectionType: String.self) { items in
            contextMenuItems(for: items)
        } primaryAction: { items in
            if let taskId = items.first {
                if let task = filteredTasks.first(where: { $0.id == taskId }) {
                    performPrimaryAction(for: task)
                }
            }
        }
        .onDeleteCommand {
            deleteSelectedTasks()
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    @ViewBuilder
    func contextMenuItems(for taskIds: Set<String>) -> some View {
        let tasks = filteredTasks.filter { taskIds.contains($0.id) }
        
        if tasks.count == 1, let task = tasks.first {
            Button("Resume") {
                Task { try await downloadManager.resumeDownload(taskId: task.id) }
            }
            .disabled(task.status == .active || task.status == .completed)
            
            Button("Pause") {
                Task { try await downloadManager.pauseDownload(taskId: task.id) }
            }
            .disabled(task.status != .active)
            
            Divider()
            
            if task.status == .completed {
                Button("Open in Finder") {
                    openInFinder(task)
                }
            }
            
            Button("Copy URL") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(task.url.absoluteString, forType: .string)
            }
            
            Divider()
        }
        
        Button("Remove") {
            deleteSelectedTasks()
        }
        .keyboardShortcut(.delete)
    }
    
    func performPrimaryAction(for task: DownloadTask) {
        switch task.status {
        case .active:
            Task { try await downloadManager.pauseDownload(taskId: task.id) }
        case .paused, .pending, .waiting, .error:
            Task { try await downloadManager.resumeDownload(taskId: task.id) }
        case .completed:
            openInFinder(task)
        default:
            break
        }
    }
    
    func deleteSelectedTasks() {
        for taskId in selection {
            Task {
                await downloadManager.removeDownload(taskId: taskId)
            }
        }
    }
    
    func openInFinder(_ task: DownloadTask) {
        NSWorkspace.shared.selectFile(
            task.destination.appendingPathComponent(task.filename).path,
            inFileViewerRootedAtPath: task.destination.path
        )
    }
    
    func iconForTask(_ task: DownloadTask) -> String {
        let ext = task.url.pathExtension.lowercased()
        switch ext {
        case "mp4", "avi", "mkv", "mov": return "video.fill"
        case "mp3", "aac", "flac", "wav": return "music.note"
        case "zip", "rar", "7z", "tar": return "archivebox.fill"
        case "pdf": return "doc.richtext.fill"
        case "dmg", "pkg", "app": return "app.badge.fill"
        default: return "doc.fill"
        }
    }
    
    func colorForStatus(_ status: TaskStatus) -> Color {
        switch status {
        case .active: return .blue
        case .paused: return .orange
        case .completed: return .green
        case .error: return .red
        case .waiting, .pending: return .gray
        default: return .secondary
        }
    }
    
    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.zeroPadsFractionDigits = false
        return formatter.string(fromByteCount: bytes)
    }
    
    func formatTimeInterval(_ interval: TimeInterval) -> String {
        if interval < 60 {
            return "\(Int(interval))s"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m"
        } else {
            let hours = Int(interval / 3600)
            let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(minutes)m"
        }
    }
}

extension TaskStatus {
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .waiting: return "Waiting"
        case .active: return "Downloading"
        case .paused: return "Paused"
        case .complete: return "Completed"
        case .completed: return "Completed"
        case .error: return "Error"
        case .removed: return "Removed"
        }
    }
}