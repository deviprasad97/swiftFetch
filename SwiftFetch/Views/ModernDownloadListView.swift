import SwiftUI
import Charts

struct ModernDownloadListView: View {
    @EnvironmentObject var downloadManager: DownloadManager
    let filter: String
    let searchText: String
    
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
            break // "all" - show all tasks
        }
        
        // Apply search
        if !searchText.isEmpty {
            tasks = tasks.filter { task in
                task.filename.localizedCaseInsensitiveContains(searchText) ||
                task.url.absoluteString.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return tasks.sorted { $0.createdAt > $1.createdAt }
    }
    
    private func filterByFileType(_ tasks: [DownloadTask], category: String) -> [DownloadTask] {
        tasks.filter { task in
            let ext = task.url.pathExtension.lowercased()
            switch category {
            case "documents":
                return ["pdf", "doc", "docx", "txt", "rtf", "odt", "pages", "tex"].contains(ext)
            case "videos":
                return ["mp4", "avi", "mkv", "mov", "wmv", "flv", "webm", "m4v", "mpg", "mpeg"].contains(ext)
            case "music":
                return ["mp3", "aac", "flac", "wav", "m4a", "ogg", "wma", "opus", "aiff"].contains(ext)
            case "archives":
                return ["zip", "rar", "7z", "tar", "gz", "bz2", "xz", "dmg"].contains(ext)
            case "software":
                return ["dmg", "pkg", "app", "exe", "msi", "deb", "rpm", "snap", "flatpak"].contains(ext)
            default:
                return false
            }
        }
    }
    
    var body: some View {
        ScrollView {
            if filteredTasks.isEmpty {
                EmptyStateView(searchText: searchText, filter: filter)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
            } else {
                LazyVStack(spacing: 1) {
                    ForEach(filteredTasks) { task in
                        ModernDownloadCard(task: task)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct EmptyStateView: View {
    let searchText: String
    let filter: String
    
    var message: String {
        if !searchText.isEmpty {
            return "No downloads matching '\(searchText)'"
        }
        switch filter {
        case "active":
            return "No active downloads"
        case "queued":
            return "No queued downloads"
        case "completed":
            return "No completed downloads"
        default:
            return "No downloads yet"
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text(message)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
            
            if searchText.isEmpty && filter == "all" {
                Text("Click the + button to add a download")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary.opacity(0.8))
            }
        }
    }
}

struct ModernDownloadCard: View {
    let task: DownloadTask
    @EnvironmentObject var downloadManager: DownloadManager
    @State private var isHovering = false
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Status Icon
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: fileIcon)
                        .font(.system(size: 20))
                        .foregroundColor(statusColor)
                }
                
                // File Info
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(task.filename)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                        
                        if task.status == .completed {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                        
                        Text(task.url.host ?? "")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    // Progress
                    if task.status != .completed {
                        ModernProgressBar(
                            progress: task.progress,
                            status: task.status,
                            segments: task.segments
                        )
                        .frame(height: 6)
                    }
                    
                    // Stats Row
                    HStack(spacing: 16) {
                        // Size
                        Text("\(formatBytes(task.completedSize)) / \(formatBytes(task.size ?? 0))")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        // Speed
                        if task.status == .active {
                            Label(formatBytes(task.downloadSpeed) + "/s", systemImage: "speedometer")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.green)
                        }
                        
                        // ETA
                        if let eta = task.eta, task.status == .active {
                            Label(formatTimeInterval(eta), systemImage: "clock")
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                        }
                        
                        Spacer()
                        
                        // Progress percentage
                        if task.status != .completed {
                            Text("\(Int(task.progress * 100))%")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Speed Chart (for active downloads)
                if task.status == .active && !task.speedHistory.isEmpty {
                    MiniSpeedChart(speedHistory: task.speedHistory)
                        .frame(width: 80, height: 40)
                }
                
                // Action Buttons
                DownloadActionButtons(task: task)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isHovering ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }
            
            // Expanded Details
            if isExpanded {
                DownloadDetailsCard(task: task)
                    .padding(.top, 1)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        }
    }
    
    var statusColor: Color {
        switch task.status {
        case .active: return .blue
        case .paused: return .orange
        case .completed: return .green
        case .error: return .red
        case .waiting, .pending: return .gray
        default: return .secondary
        }
    }
    
    var fileIcon: String {
        let ext = task.url.pathExtension.lowercased()
        switch ext {
        case "mp4", "avi", "mkv", "mov": return "video.fill"
        case "mp3", "aac", "flac", "wav": return "music.note"
        case "zip", "rar", "7z", "tar": return "archivebox.fill"
        case "pdf": return "doc.richtext.fill"
        case "dmg", "pkg", "app": return "app.badge.fill"
        case "jpg", "png", "gif", "svg": return "photo.fill"
        default: return "doc.fill"
        }
    }
    
    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.zeroPadsFractionDigits = false
        return formatter.string(fromByteCount: bytes)
    }
    
    func formatTimeInterval(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter.string(from: interval) ?? "—"
    }
}

struct ModernProgressBar: View {
    let progress: Double
    let status: TaskStatus
    let segments: Int
    
    var progressColor: Color {
        switch status {
        case .active: return .blue
        case .paused: return .orange
        case .error: return .red
        default: return .gray
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 3)
                    .fill(progressColor.opacity(0.15))
                
                // Progress
                RoundedRectangle(cornerRadius: 3)
                    .fill(progressColor)
                    .frame(width: geometry.size.width * CGFloat(progress))
                
                // Segments
                if segments > 1 {
                    HStack(spacing: 1) {
                        ForEach(1..<segments, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.white.opacity(0.3))
                                .frame(width: 1)
                        }
                    }
                }
            }
        }
    }
}

struct MiniSpeedChart: View {
    let speedHistory: [SpeedDataPoint]
    
    var chartData: [SpeedChartPoint] {
        speedHistory.suffix(20).enumerated().map { index, point in
            SpeedChartPoint(
                time: Double(index),
                speed: Double(point.speed) / 1_048_576 // Convert to MB/s
            )
        }
    }
    
    var body: some View {
        Chart(chartData) { point in
            LineMark(
                x: .value("Time", point.time),
                y: .value("Speed", point.speed)
            )
            .foregroundStyle(.green)
            
            AreaMark(
                x: .value("Time", point.time),
                y: .value("Speed", point.speed)
            )
            .foregroundStyle(.linearGradient(
                colors: [.green.opacity(0.3), .green.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            ))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }
}

struct SpeedChartPoint: Identifiable {
    let id = UUID()
    let time: Double
    let speed: Double
}

struct DownloadActionButtons: View {
    let task: DownloadTask
    @EnvironmentObject var downloadManager: DownloadManager
    @State private var showingMenu = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Primary Action
            Button(action: { performPrimaryAction() }) {
                Image(systemName: primaryActionIcon)
                    .font(.system(size: 14))
            }
            .buttonStyle(IconButtonStyle(color: primaryActionColor))
            
            // Menu
            Menu {
                Button("Copy URL") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(task.url.absoluteString, forType: .string)
                }
                
                Button("Open in Browser") {
                    NSWorkspace.shared.open(task.url)
                }
                
                if task.status == .completed {
                    Button("Show in Finder") {
                        NSWorkspace.shared.selectFile(
                            task.destination.appendingPathComponent(task.filename).path,
                            inFileViewerRootedAtPath: task.destination.path
                        )
                    }
                }
                
                Divider()
                
                Button("Remove", role: .destructive) {
                    Task {
                        await downloadManager.removeDownload(taskId: task.id)
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14))
            }
            .buttonStyle(IconButtonStyle(color: .secondary))
            .menuStyle(.borderlessButton)
        }
    }
    
    var primaryActionIcon: String {
        switch task.status {
        case .active: return "pause.fill"
        case .paused, .pending, .waiting: return "play.fill"
        case .completed: return "folder.fill"
        case .error: return "arrow.clockwise"
        default: return "play.fill"
        }
    }
    
    var primaryActionColor: Color {
        switch task.status {
        case .active: return .orange
        case .completed: return .blue
        case .error: return .red
        default: return .green
        }
    }
    
    func performPrimaryAction() {
        Task {
            switch task.status {
            case .active:
                try await downloadManager.pauseDownload(taskId: task.id)
            case .paused, .pending, .waiting, .error:
                try await downloadManager.resumeDownload(taskId: task.id)
            case .completed:
                NSWorkspace.shared.selectFile(
                    task.destination.appendingPathComponent(task.filename).path,
                    inFileViewerRootedAtPath: task.destination.path
                )
            default:
                break
            }
        }
    }
}

struct IconButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(color)
            .padding(6)
            .background(
                Circle()
                    .fill(configuration.isPressed ? 
                          color.opacity(0.2) : 
                          color.opacity(0.1))
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

struct DownloadDetailsCard: View {
    let task: DownloadTask
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ModernDetailRow(label: "URL", value: task.url.absoluteString, canCopy: true)
            ModernDetailRow(label: "Destination", value: task.destination.path)
            ModernDetailRow(label: "Started", value: task.startedAt?.formatted() ?? "—")
            if let completed = task.completedAt {
                ModernDetailRow(label: "Completed", value: completed.formatted())
            }
            if let error = task.errorMessage {
                ModernDetailRow(label: "Error", value: error)
                    .foregroundColor(.red)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

struct ModernDetailRow: View {
    let label: String
    let value: String
    var canCopy: Bool = false
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.system(size: 12))
                .textSelection(.enabled)
                .lineLimit(2)
            
            if canCopy {
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(value, forType: .string)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}