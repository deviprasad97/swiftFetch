import Foundation
import SwiftUI
import Combine

@MainActor
class DownloadManager: ObservableObject {
    static let shared = DownloadManager()
    
    @Published var tasks: [DownloadTask] = []
    @Published var activeTasks: [DownloadTask] = []
    @Published var queuedTasks: [DownloadTask] = []
    @Published var completedTasks: [DownloadTask] = []
    @Published var globalStats = GlobalStats()
    @Published var showNewDownloadSheet = false
    @Published var showBatchImport = false
    @Published var showSettings = false
    @Published var selectedCategory: Category?
    
    private var aria2Client: Aria2Client?
    private var segmentController = SegmentController()
    private var updateTimer: Timer?
    private let storage = SimpleStorageManager()
    private var aria2Running = false
    
    struct GlobalStats {
        var downloadSpeed: Int64 = 0
        var uploadSpeed: Int64 = 0
        var numActive: Int = 0
        var numWaiting: Int = 0
        var numStopped: Int = 0
        
        var formattedDownloadSpeed: String {
            let formatter = ByteCountFormatter()
            formatter.countStyle = .binary
            return formatter.string(fromByteCount: downloadSpeed) + "/s"
        }
    }
    
    func initialize() async {
        print("🚀 Initializing DownloadManager...")
        
        // Start aria2 if not running
        await startAria2()
        
        // Connect RPC client
        aria2Client = Aria2Client()
        
        // Load saved tasks from storage
        await loadTasks()
        
        // Reconnect active tasks to aria2
        await reconnectActiveTasks()
        
        // Start update timer
        startUpdateTimer()
        
        print("✅ DownloadManager initialized successfully")
    }
    
    private func reconnectActiveTasks() async {
        // For tasks that were active, try to reconnect to aria2
        for task in tasks where task.status == .active || task.status == .paused {
            // Check if aria2 still knows about this task
            if let gid = task.gid, let client = aria2Client {
                do {
                    _ = try await client.tellStatus(gid: gid)
                } catch {
                    // Task no longer in aria2, mark as interrupted
                    if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                        await MainActor.run {
                            tasks[index].status = .paused
                            tasks[index].errorMessage = "Download interrupted"
                        }
                    }
                }
            }
        }
    }
    
    private func startAria2() async {
        // First check if aria2 is already running
        let testClient = Aria2Client()
        do {
            _ = try await testClient.getGlobalStat()
            print("✅ aria2 is already running")
            aria2Running = true
            return
        } catch {
            print("📝 aria2 not detected, starting it...")
        }
        
        let fileManager = FileManager.default
        var aria2Path: String?
        
        // First check for bundled aria2
        if let bundledPath = Bundle.main.resourcePath?.appending("/aria2c") {
            if fileManager.fileExists(atPath: bundledPath) {
                aria2Path = bundledPath
                print("✅ Using bundled aria2 from: \(bundledPath)")
            }
        }
        
        // Fallback to system aria2
        if aria2Path == nil {
            let systemPaths = [
                "/usr/local/bin/aria2c",
                "/opt/homebrew/bin/aria2c",
                "/usr/bin/aria2c",
                "/opt/homebrew/Cellar/aria2/1.37.0/bin/aria2c"
            ]
            
            for path in systemPaths {
                if fileManager.fileExists(atPath: path) {
                    aria2Path = path
                    print("✅ Using system aria2 from: \(path)")
                    break
                }
            }
        }
        
        guard let executablePath = aria2Path else {
            print("⚠️ aria2 not found. Please install aria2 or bundle it with the app.")
            aria2Running = false
            return
        }
        
        // Kill any existing aria2 processes first
        let killTask = Process()
        killTask.launchPath = "/usr/bin/pkill"
        killTask.arguments = ["-f", "aria2c.*--enable-rpc"]
        try? killTask.run()
        killTask.waitUntilExit()
        
        // Start aria2 in daemon mode
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        
        // Use daemon mode for silent background operation
        process.arguments = [
            "--enable-rpc",
            "--rpc-listen-port=6800",
            "--rpc-allow-origin-all=true",
            "--rpc-listen-all=false",
            "--max-concurrent-downloads=5",
            "--daemon=true",
            "--log-level=error"
        ]
        
        do {
            try process.run()
            process.waitUntilExit()
            
            // Wait for aria2 to start
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            // Verify it's running
            _ = try await testClient.getGlobalStat()
            print("✅ aria2 started successfully in daemon mode")
            aria2Running = true
        } catch {
            print("⚠️ Failed to start aria2: \(error)")
            aria2Running = false
            
            // Try one more time with shell command
            startAria2Manually()
        }
    }
    
    private func startAria2Manually() {
        Task {
            do {
                // Determine aria2 path
                var aria2Path = "/opt/homebrew/bin/aria2c"
                if let bundledPath = Bundle.main.resourcePath?.appending("/aria2c"),
                   FileManager.default.fileExists(atPath: bundledPath) {
                    aria2Path = bundledPath
                }
                
                // Start aria2 using shell command
                let task = Process()
                task.launchPath = "/bin/sh"
                task.arguments = ["-c", "\(aria2Path) --enable-rpc --rpc-listen-port=6800 --daemon"]
                try task.run()
                
                // Wait a bit for aria2 to start
                try await Task.sleep(nanoseconds: 2_000_000_000)
                
                // Test connection
                let testClient = Aria2Client()
                _ = try await testClient.getGlobalStat()
                
                print("✅ aria2 started successfully via shell")
                aria2Running = true
            } catch {
                print("⚠️ Could not start aria2 daemon: \(error)")
                print("You can manually start aria2 with: aria2c --enable-rpc --rpc-listen-port=6800")
            }
        }
    }
    
    private func startUpdateTimer() {
        // Reduce update frequency to minimize socket warnings
        updateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task {
                await self.updateStatus()
            }
        }
    }
    
    private func updateStatus() async {
        // Don't try to update if aria2 isn't running
        guard aria2Running, let client = aria2Client else { return }
        
        do {
            // Get global stats
            let stats = try await client.getGlobalStat()
            await MainActor.run {
                self.globalStats = GlobalStats(
                    downloadSpeed: stats.downloadSpeed,
                    uploadSpeed: stats.uploadSpeed,
                    numActive: stats.numActive,
                    numWaiting: stats.numWaiting,
                    numStopped: stats.numStopped
                )
            }
            
            // Update all tasks with GIDs
            for i in tasks.indices where tasks[i].gid != nil {
                if let gid = tasks[i].gid {
                    do {
                        let aria2Status = try await client.tellStatus(gid: gid)
                        await updateTask(with: aria2Status)
                    } catch {
                        // Task might be removed from aria2
                        continue
                    }
                }
            }
            
            // Categorize tasks
            await MainActor.run {
                self.activeTasks = self.tasks.filter { $0.status == .active }
                self.queuedTasks = self.tasks.filter { $0.status == .waiting || $0.status == .pending || $0.status == .paused }
                self.completedTasks = self.tasks.filter { $0.status == .completed || $0.status == .complete }
            }
        } catch {
            print("Failed to update status: \\(error)")
        }
    }
    
    private func updateTask(with aria2Status: Aria2Status) async {
        await MainActor.run {
            if let index = tasks.firstIndex(where: { $0.gid == aria2Status.gid }) {
                let oldSize = tasks[index].size ?? 0
                let oldCompleted = tasks[index].completedSize
                
                tasks[index].completedSize = aria2Status.completedLength
                tasks[index].size = aria2Status.totalLength > 0 ? aria2Status.totalLength : tasks[index].size
                tasks[index].status = TaskStatus(aria2Status: aria2Status.status)
                tasks[index].downloadSpeed = aria2Status.downloadSpeed
                tasks[index].uploadSpeed = aria2Status.uploadSpeed
                
                // Calculate ETA
                if aria2Status.downloadSpeed > 0 && tasks[index].size != nil {
                    let remaining = (tasks[index].size ?? 0) - tasks[index].completedSize
                    tasks[index].eta = TimeInterval(remaining / aria2Status.downloadSpeed)
                }
                
                // Track speed history (keep last 60 data points)
                if tasks[index].status == .active && aria2Status.downloadSpeed > 0 {
                    tasks[index].speedHistory.append(SpeedDataPoint(speed: aria2Status.downloadSpeed))
                    if tasks[index].speedHistory.count > 60 {
                        tasks[index].speedHistory.removeFirst()
                    }
                }
                
                // Log progress changes
                if oldSize != tasks[index].size || oldCompleted != tasks[index].completedSize {
                    let progress = tasks[index].progress * 100
                    print("📥 \(tasks[index].filename): \(formatBytes(tasks[index].completedSize))/\(formatBytes(tasks[index].size ?? 0)) (\(String(format: "%.1f", progress))%)")
                }
                
                // Save task updates to database only if there were actual changes
                if oldSize != tasks[index].size || oldCompleted != tasks[index].completedSize || 
                   tasks[index].status == .completed || tasks[index].status == .error {
                    Task {
                        await self.storage.saveTask(self.tasks[index])
                    }
                }
                
                // Adjust segments based on performance
                if tasks[index].status == .active {
                    let newSegments = segmentController.adjustSegments(
                        currentSpeed: Double(aria2Status.downloadSpeed),
                        fileSize: aria2Status.totalLength
                    )
                    
                    if newSegments != tasks[index].segments {
                        Task {
                            await self.updateSegments(
                                taskId: tasks[index].id,
                                segments: newSegments
                            )
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Public Methods
    
    func addDownload(
        url: URL,
        options: DownloadOptions = DownloadOptions()
    ) async throws -> DownloadTask {
        guard let client = aria2Client else {
            throw DownloadError.notInitialized
        }
        
        // Create task
        var task = DownloadTask(
            url: url,
            filename: options.filename,
            destination: options.destination ?? getDefaultDownloadPath(),
            segments: options.segments
        )
        
        // Prepare aria2 options
        var aria2Options: [String: Any] = [
            "dir": task.destination.path,
            "out": task.filename,
            "split": String(task.segments),
            "max-connection-per-server": String(task.segments)
        ]
        
        if let speedLimit = options.speedLimit {
            aria2Options["max-download-limit"] = String(speedLimit)
        }
        
        if let cookies = options.cookies {
            aria2Options["header"] = "Cookie: \\(cookies)"
        }
        
        if let referrer = options.referrer {
            aria2Options["referer"] = referrer
        }
        
        // Add to aria2
        let gid = try await client.addUri(
            urls: [url.absoluteString],
            options: aria2Options
        )
        
        task.gid = gid
        
        // Get the actual status from aria2
        let aria2Status = try await client.tellStatus(gid: gid)
        task.status = TaskStatus(aria2Status: aria2Status.status)
        task.size = aria2Status.totalLength
        
        // Save to database
        await storage.saveTask(task)
        
        // Add to task list
        await MainActor.run {
            tasks.append(task)
        }
        
        return task
    }
    
    func pauseDownload(taskId: String) async throws {
        guard let client = aria2Client,
              let task = tasks.first(where: { $0.id == taskId }),
              let gid = task.gid else {
            throw DownloadError.taskNotFound
        }
        
        _ = try await client.pause(gid: gid)
        
        await MainActor.run {
            if let index = tasks.firstIndex(where: { $0.id == taskId }) {
                tasks[index].status = .paused
            }
        }
    }
    
    func resumeDownload(taskId: String) async throws {
        guard let client = aria2Client,
              let task = tasks.first(where: { $0.id == taskId }),
              let gid = task.gid else {
            throw DownloadError.taskNotFound
        }
        
        _ = try await client.unpause(gid: gid)
        
        await MainActor.run {
            if let index = tasks.firstIndex(where: { $0.id == taskId }) {
                tasks[index].status = .active
            }
        }
    }
    
    func cancelDownload(taskId: String) async throws {
        guard let task = tasks.first(where: { $0.id == taskId }) else {
            throw DownloadError.taskNotFound
        }
        
        // Try to remove from aria2 if it has a GID
        if let client = aria2Client, let gid = task.gid {
            do {
                _ = try await client.remove(gid: gid)
            } catch {
                // Log error but continue with removal
                print("Warning: Could not remove from aria2: \(error)")
            }
        }
        
        // Remove from UI
        await MainActor.run {
            tasks.removeAll(where: { $0.id == taskId })
        }
        
        // Remove from database
        await storage.deleteTask(taskId)
    }
    
    func removeDownload(taskId: String) async {
        // Non-throwing version for UI
        do {
            try await cancelDownload(taskId: taskId)
        } catch {
            print("Error removing download: \(error)")
            // Still try to remove from UI even if aria2 fails
            await MainActor.run {
                tasks.removeAll(where: { $0.id == taskId })
            }
            await storage.deleteTask(taskId)
        }
    }
    
    func setGlobalSpeedLimit(_ limit: Int?) async throws {
        guard let client = aria2Client else {
            throw DownloadError.notInitialized
        }
        
        let options = limit != nil 
            ? ["max-overall-download-limit": String(limit!)]
            : ["max-overall-download-limit": "0"]
        
        _ = try await client.changeGlobalOption(options: options)
    }
    
    private func updateSegments(taskId: String, segments: Int) async {
        // This would require removing and re-adding the download
        // with new segment count in aria2
        // print("Updating segments for \(taskId) to \(segments)")
        // Disabled for now as it's called too frequently
    }
    
    func handleBrowserDownload(_ request: BrowserDownloadRequest) async {
        do {
            _ = try await addDownload(
                url: URL(string: request.url)!,
                options: DownloadOptions(
                    filename: request.filename,
                    cookies: request.cookies,
                    referrer: request.referrer
                )
            )
        } catch {
            print("Failed to add browser download: \\(error)")
        }
    }
    
    func importFromFile() {
        // Show file picker and import URLs
    }
    
    func startAll() async {
        for task in queuedTasks {
            try? await resumeDownload(taskId: task.id)
        }
    }
    
    func pauseAll() async {
        for task in activeTasks {
            try? await pauseDownload(taskId: task.id)
        }
    }
    
    private func loadTasks() async {
        print("📚 Loading tasks from storage...")
        let savedTasks = await storage.loadTasks()
        print("📚 Loaded \(savedTasks.count) tasks from database")
        
        await MainActor.run {
            self.tasks = savedTasks
            
            // Categorize loaded tasks
            self.activeTasks = self.tasks.filter { $0.status == .active }
            self.queuedTasks = self.tasks.filter { $0.status == .waiting || $0.status == .pending || $0.status == .paused }
            self.completedTasks = self.tasks.filter { $0.status == .completed || $0.status == .complete }
            
            print("📊 Active: \(self.activeTasks.count), Queued: \(self.queuedTasks.count), Completed: \(self.completedTasks.count)")
        }
    }
    
    private func getDefaultDownloadPath() -> URL {
        let fileManager = FileManager.default
        let downloadsDir = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        
        // Create SwiftFetch subdirectory in Downloads
        let swiftFetchDownloads = downloadsDir.appendingPathComponent("SwiftFetch Downloads")
        
        if !fileManager.fileExists(atPath: swiftFetchDownloads.path) {
            do {
                try fileManager.createDirectory(at: swiftFetchDownloads,
                                              withIntermediateDirectories: true,
                                              attributes: nil)
                print("✅ Created download directory: \(swiftFetchDownloads.path)")
            } catch {
                print("⚠️ Could not create download directory, using default: \(error)")
                return downloadsDir
            }
        }
        
        return swiftFetchDownloads
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Supporting Types

struct DownloadOptions {
    var destination: URL?
    var filename: String?
    var segments: Int = 8
    var speedLimit: Int?
    var headers: [String: String] = [:]
    var cookies: String?
    var referrer: String?
    var checksum: Checksum?
    var category: Category?
    var schedule: DownloadSchedule?
    var postActions: [PostAction] = []
}

struct BrowserDownloadRequest {
    let url: String
    let filename: String?
    let referrer: String?
    let cookies: String?
    let userAgent: String?
    let tabUrl: String?
    let tabTitle: String?
}

enum DownloadError: Error {
    case notInitialized
    case taskNotFound
    case invalidURL
    case aria2Error(String)
}

class SegmentController {
    private var currentSegments: Int = 4
    private let minSegments = 1
    private let maxSegments = 16
    private var throughputHistory: [Double] = []
    
    func adjustSegments(currentSpeed: Double, fileSize: Int64) -> Int {
        throughputHistory.append(currentSpeed)
        
        if throughputHistory.count > 10 {
            throughputHistory.removeFirst()
        }
        
        guard throughputHistory.count >= 3 else {
            return currentSegments
        }
        
        let avgSpeed = throughputHistory.reduce(0, +) / Double(throughputHistory.count)
        let speedVariance = calculateVariance(throughputHistory)
        
        // High variance indicates congestion
        if speedVariance > 0.3 * avgSpeed {
            currentSegments = max(minSegments, currentSegments * 3 / 4)
        } else if speedVariance < 0.1 * avgSpeed {
            currentSegments = min(maxSegments, currentSegments + 1)
        }
        
        // File size consideration
        let bytesPerSegment = fileSize / Int64(currentSegments)
        if bytesPerSegment < 1_048_576 { // Less than 1MB per segment
            currentSegments = max(1, Int(fileSize / 1_048_576))
        }
        
        return currentSegments
    }
    
    private func calculateVariance(_ values: [Double]) -> Double {
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDiffs = values.map { pow($0 - mean, 2) }
        return squaredDiffs.reduce(0, +) / Double(values.count)
    }
}