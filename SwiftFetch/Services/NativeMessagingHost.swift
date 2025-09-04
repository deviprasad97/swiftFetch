import Foundation
import AppKit

// Native Messaging Host for SwiftFetch
// Handles communication between browser extension and SwiftFetch app

class NativeMessagingHost {
    private let downloadManager: DownloadManager
    private var inputStream = FileHandle.standardInput
    private var outputStream = FileHandle.standardOutput
    private var shouldExit = false
    
    init(downloadManager: DownloadManager) {
        self.downloadManager = downloadManager
    }
    
    func start() {
        print("🚀 SwiftFetch Native Messaging Host started", to: &standardError)
        
        // Main message loop
        while !shouldExit {
            autoreleasepool {
                if let message = readMessage() {
                    handleMessage(message)
                }
            }
        }
    }
    
    // Read message from stdin (Chrome native messaging format)
    private func readMessage() -> [String: Any]? {
        // Read 4-byte message length
        let lengthData = inputStream.readData(ofLength: 4)
        guard lengthData.count == 4 else {
            print("❌ Failed to read message length", to: &standardError)
            shouldExit = true
            return nil
        }
        
        // Convert to UInt32 (little-endian)
        let length = lengthData.withUnsafeBytes { bytes in
            bytes.load(as: UInt32.self)
        }
        
        guard length > 0 && length < 1024 * 1024 else { // Max 1MB message
            print("❌ Invalid message length: \(length)", to: &standardError)
            return nil
        }
        
        // Read message body
        let messageData = inputStream.readData(ofLength: Int(length))
        guard messageData.count == Int(length) else {
            print("❌ Failed to read complete message", to: &standardError)
            return nil
        }
        
        // Parse JSON
        do {
            let json = try JSONSerialization.jsonObject(with: messageData, options: [])
            return json as? [String: Any]
        } catch {
            print("❌ Failed to parse JSON: \(error)", to: &standardError)
            return nil
        }
    }
    
    // Send message to stdout
    private func sendMessage(_ message: [String: Any]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: message, options: [])
            
            // Write 4-byte message length (little-endian)
            var length = UInt32(data.count)
            let lengthData = Data(bytes: &length, count: 4)
            
            outputStream.write(lengthData)
            outputStream.write(data)
            outputStream.synchronizeFile()
        } catch {
            print("❌ Failed to send message: \(error)", to: &standardError)
        }
    }
    
    // Handle incoming message
    private func handleMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else {
            sendError("Invalid message format")
            return
        }
        
        print("📨 Received message type: \(type)", to: &standardError)
        
        switch type {
        case "ping":
            sendMessage(["type": "pong", "timestamp": Date().timeIntervalSince1970])
            
        case "download":
            handleDownload(message)
            
        case "batch":
            handleBatchDownload(message)
            
        case "downloadVideo":
            handleVideoDownload(message)
            
        case "get_status":
            sendStatus()
            
        case "pause":
            if let taskId = message["taskId"] as? String {
                pauseDownload(taskId)
            }
            
        case "resume":
            if let taskId = message["taskId"] as? String {
                resumeDownload(taskId)
            }
            
        case "cancel":
            if let taskId = message["taskId"] as? String {
                cancelDownload(taskId)
            }
            
        default:
            sendError("Unknown message type: \(type)")
        }
    }
    
    // Handle download request
    private func handleDownload(_ message: [String: Any]) {
        guard let urlString = message["url"] as? String,
              let url = URL(string: urlString) else {
            sendError("Invalid URL")
            return
        }
        
        // Create download options
        var options = DownloadOptions()
        
        if let filename = message["filename"] as? String {
            options.customFilename = filename
        }
        
        if let referrer = message["referrer"] as? String {
            options.referrer = referrer
        }
        
        if let cookies = message["cookies"] as? String {
            options.cookies = cookies
        }
        
        if let userAgent = message["userAgent"] as? String {
            options.userAgent = userAgent
        }
        
        // Add download
        Task { @MainActor in
            do {
                let taskId = try await downloadManager.addDownload(url: url, options: options)
                
                sendMessage([
                    "type": "download_started",
                    "taskId": taskId,
                    "url": urlString,
                    "message": "Download started"
                ])
            } catch {
                sendError("Failed to start download: \(error.localizedDescription)")
            }
        }
    }
    
    // Handle batch download
    private func handleBatchDownload(_ message: [String: Any]) {
        guard let urls = message["urls"] as? [String] else {
            sendError("Invalid batch download request")
            return
        }
        
        var successCount = 0
        
        Task { @MainActor in
            for urlString in urls {
                if let url = URL(string: urlString) {
                    do {
                        _ = try await downloadManager.addDownload(url: url)
                        successCount += 1
                    } catch {
                        print("Failed to add \(urlString): \(error)", to: &standardError)
                    }
                }
            }
            
            sendMessage([
                "type": "batch_started",
                "count": successCount,
                "total": urls.count,
                "message": "Batch download started: \(successCount) of \(urls.count) files"
            ])
        }
    }
    
    // Handle video download (will use yt-dlp in Phase 2)
    private func handleVideoDownload(_ message: [String: Any]) {
        guard let urlString = message["url"] as? String else {
            sendError("Invalid video URL")
            return
        }
        
        let title = message["title"] as? String ?? "Video"
        
        // For now, just use regular download
        // TODO: Integrate yt-dlp in Phase 2
        handleDownload(message)
        
        sendMessage([
            "type": "video_queued",
            "url": urlString,
            "title": title,
            "message": "Video download queued (yt-dlp integration coming soon)"
        ])
    }
    
    // Send current status
    private func sendStatus() {
        Task { @MainActor in
            let tasks = downloadManager.tasks.map { task in
                [
                    "id": task.id,
                    "url": task.url.absoluteString,
                    "filename": task.filename,
                    "status": task.status.rawValue,
                    "progress": task.progress,
                    "size": task.size ?? 0,
                    "completedSize": task.completedSize,
                    "speed": task.downloadSpeed
                ]
            }
            
            sendMessage([
                "type": "status",
                "tasks": tasks,
                "activeCount": downloadManager.activeTasks.count,
                "queuedCount": downloadManager.queuedTasks.count,
                "completedCount": downloadManager.completedTasks.count
            ])
        }
    }
    
    // Pause download
    private func pauseDownload(_ taskId: String) {
        Task { @MainActor in
            await downloadManager.pauseDownload(taskId: taskId)
            sendMessage([
                "type": "download_paused",
                "taskId": taskId
            ])
        }
    }
    
    // Resume download
    private func resumeDownload(_ taskId: String) {
        Task { @MainActor in
            await downloadManager.resumeDownload(taskId: taskId)
            sendMessage([
                "type": "download_resumed",
                "taskId": taskId
            ])
        }
    }
    
    // Cancel download
    private func cancelDownload(_ taskId: String) {
        Task { @MainActor in
            await downloadManager.removeDownload(taskId: taskId)
            sendMessage([
                "type": "download_cancelled",
                "taskId": taskId
            ])
        }
    }
    
    // Send error message
    private func sendError(_ error: String) {
        sendMessage([
            "type": "error",
            "message": error
        ])
    }
}

// Extension to print to stderr
extension FileHandle: TextOutputStream {
    public func write(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        self.write(data)
    }
}

var standardError = FileHandle.standardError