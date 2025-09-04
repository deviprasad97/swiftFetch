import SwiftUI
import Charts

struct DownloadListView: View {
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
        case let schedule where schedule.starts(with: "schedule."):
            let scheduleName = String(schedule.dropFirst(9))
            tasks = filterBySchedule(tasks, schedule: scheduleName)
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
        
        return tasks
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
    
    private func filterBySchedule(_ tasks: [DownloadTask], schedule: String) -> [DownloadTask] {
        switch schedule {
        case "now":
            return tasks.filter { $0.status == .active }
        case "night":
            // Would filter by scheduled downloads for nighttime
            return []
        case "weekend":
            // Would filter by scheduled downloads for weekend
            return []
        default:
            return tasks
        }
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filteredTasks) { task in
                    DownloadRowView(task: task)
                }
            }
            .padding()
        }
        .background(Color(NSColor.windowBackgroundColor))
        .overlay {
            if filteredTasks.isEmpty {
                ContentUnavailableView {
                    Label("No Downloads", systemImage: "arrow.down.circle")
                } description: {
                    Text(searchText.isEmpty ? "Add downloads to get started" : "No downloads matching '\(searchText)'")
                }
            }
        }
    }
}

struct DownloadRowView: View {
    let task: DownloadTask
    @EnvironmentObject var downloadManager: DownloadManager
    @State private var isExpanded = false
    @State private var isHovering = false
    
    var speedData: [SpeedPoint] {
        task.speedHistory.enumerated().map { index, dataPoint in
            SpeedPoint(
                time: Double(index),
                speed: Double(dataPoint.speed) / 1_048_576 // Convert to MB/s for display
            )
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(spacing: 12) {
                // File icon
                Image(systemName: iconForTask(task))
                    .font(.title2)
                    .foregroundColor(.accentColor)
                    .frame(width: 32)
                
                // File info and progress
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(task.filename)
                            .font(.system(.body, weight: .medium))
                            .lineLimit(1)
                        
                        if task.status == .completed {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                        
                        Spacer()
                    }
                    
                    // Progress bar with segments
                    SegmentedProgressView(
                        progress: task.progress,
                        segments: task.segments,
                        status: task.status
                    )
                    .frame(height: 6)
                    
                    // Stats
                    HStack(spacing: 16) {
                        Text(formatBytes(task.completedSize) + " / " + formatBytes(task.size ?? 0))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if task.status == .active {
                            Text(formatBytes(task.downloadSpeed) + "/s")
                                .font(.caption)
                                .foregroundColor(.green)
                            
                            if let eta = task.eta {
                                Text("ETA: \(formatTimeInterval(eta))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Text(task.url.host ?? "")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Speed graph (for active downloads)
                if task.status == .active {
                    SpeedGraphView(data: speedData)
                        .frame(width: 100, height: 40)
                }
                
                // Action buttons
                HStack(spacing: 8) {
                    switch task.status {
                    case .active:
                        Button(action: { pauseTask(task) }) {
                            Image(systemName: "pause.fill")
                        }
                        .buttonStyle(.borderless)
                        
                    case .paused, .pending, .waiting:
                        Button(action: { resumeTask(task) }) {
                            Image(systemName: "play.fill")
                        }
                        .buttonStyle(.borderless)
                        
                    case .completed:
                        Button(action: { openInFinder(task) }) {
                            Image(systemName: "folder")
                        }
                        .buttonStyle(.borderless)
                        
                    default:
                        EmptyView()
                    }
                    
                    Menu {
                        Button("Copy URL") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(task.url.absoluteString, forType: .string)
                        }
                        
                        Button("Open in Browser") {
                            NSWorkspace.shared.open(task.url)
                        }
                        
                        Divider()
                        
                        if task.status != .completed {
                            Button("Change Priority") {
                                // Change priority
                            }
                            
                            Button("Set Speed Limit") {
                                // Set speed limit
                            }
                        }
                        
                        Divider()
                        
                        Button("Remove", role: .destructive) {
                            removeTask(task)
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .buttonStyle(.borderless)
                    .menuStyle(.borderlessButton)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isHovering ? Color(NSColor.controlAccentColor).opacity(0.1) : Color.clear)
            .onHover { hovering in
                isHovering = hovering
            }
            
            // Expanded details
            if isExpanded {
                DownloadDetailsView(task: task)
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
        .onTapGesture {
            withAnimation {
                isExpanded.toggle()
            }
        }
    }
    
    func iconForTask(_ task: DownloadTask) -> String {
        let ext = task.url.pathExtension.lowercased()
        switch ext {
        case "mp4", "avi", "mkv", "mov":
            return "video"
        case "mp3", "aac", "flac", "wav":
            return "music.note"
        case "zip", "rar", "7z", "tar", "gz":
            return "archivebox"
        case "pdf":
            return "doc.richtext"
        case "dmg", "pkg", "app":
            return "app"
        case "iso":
            return "opticaldisc"
        default:
            return "doc"
        }
    }
    
    func pauseTask(_ task: DownloadTask) {
        Task {
            try await downloadManager.pauseDownload(taskId: task.id)
        }
    }
    
    func resumeTask(_ task: DownloadTask) {
        Task {
            try await downloadManager.resumeDownload(taskId: task.id)
        }
    }
    
    func removeTask(_ task: DownloadTask) {
        Task {
            await downloadManager.removeDownload(taskId: task.id)
        }
    }
    
    func openInFinder(_ task: DownloadTask) {
        NSWorkspace.shared.selectFile(
            task.destination.appendingPathComponent(task.filename).path,
            inFileViewerRootedAtPath: task.destination.path
        )
    }
    
    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
    
    func formatTimeInterval(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter.string(from: interval) ?? "Unknown"
    }
}

struct SegmentedProgressView: View {
    let progress: Double
    let segments: Int
    let status: TaskStatus
    
    var segmentColors: [Color] {
        switch status {
        case .active:
            return Array(repeating: .green, count: segments)
        case .paused:
            return Array(repeating: .orange, count: segments)
        case .error:
            return Array(repeating: .red, count: segments)
        case .completed:
            return Array(repeating: .blue, count: segments)
        default:
            return Array(repeating: .gray, count: segments)
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(0..<segments, id: \.self) { segment in
                    let segmentProgress = calculateSegmentProgress(segment)
                    
                    Rectangle()
                        .fill(segmentColors[segment].opacity(segmentProgress > 0 ? 1 : 0.2))
                        .overlay(
                            GeometryReader { geo in
                                Rectangle()
                                    .fill(segmentColors[segment])
                                    .frame(width: geo.size.width * segmentProgress)
                            }
                        )
                }
            }
        }
        .cornerRadius(3)
    }
    
    func calculateSegmentProgress(_ segment: Int) -> Double {
        let segmentSize = 1.0 / Double(segments)
        let segmentStart = Double(segment) * segmentSize
        let segmentEnd = segmentStart + segmentSize
        
        if progress >= segmentEnd {
            return 1.0
        } else if progress > segmentStart {
            return (progress - segmentStart) / segmentSize
        } else {
            return 0.0
        }
    }
}

struct SpeedGraphView: View {
    let data: [SpeedPoint]
    
    var body: some View {
        Chart(data) { point in
            LineMark(
                x: .value("Time", point.time),
                y: .value("Speed", point.speed)
            )
            .foregroundStyle(.green)
            .lineStyle(StrokeStyle(lineWidth: 1))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartXScale(domain: 0...20)
        .chartYScale(domain: 0...10)
    }
}

struct SpeedPoint: Identifiable {
    let id = UUID()
    let time: Double
    let speed: Double
}

struct DownloadDetailsView: View {
    let task: DownloadTask
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DetailRow(label: "URL", value: task.url.absoluteString)
            DetailRow(label: "Destination", value: task.destination.path)
            DetailRow(label: "Created", value: task.createdAt.formatted())
            
            if let startedAt = task.startedAt {
                DetailRow(label: "Started", value: startedAt.formatted())
            }
            
            if let completedAt = task.completedAt {
                DetailRow(label: "Completed", value: completedAt.formatted())
            }
            
            if let errorMessage = task.errorMessage {
                DetailRow(label: "Error", value: errorMessage)
                    .foregroundColor(.red)
            }
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .trailing)
            
            Text(value)
                .font(.caption)
                .textSelection(.enabled)
            
            Spacer()
        }
    }
}