import Foundation

// Native Messaging Host for browser extensions
// Communicates via stdin/stdout with length-prefixed JSON messages

class NativeMessageHost {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var shouldExit = false
    
    func run() {
        // Set stdin to unbuffered mode
        setbuf(stdin, nil)
        setbuf(stdout, nil)
        
        while !shouldExit {
            guard let message = readMessage() else {
                break
            }
            
            handleMessage(message)
        }
    }
    
    private func readMessage() -> [String: Any]? {
        // Read 4-byte message length (native byte order)
        var lengthBytes = [UInt8](repeating: 0, count: 4)
        let bytesRead = fread(&lengthBytes, 1, 4, stdin)
        
        guard bytesRead == 4 else {
            return nil
        }
        
        let messageLength = lengthBytes.withUnsafeBytes { bytes in
            bytes.load(as: UInt32.self)
        }
        
        guard messageLength > 0 && messageLength < 1_048_576 else {
            // Sanity check: messages should be under 1MB
            return nil
        }
        
        // Read message content
        var messageBytes = [UInt8](repeating: 0, count: Int(messageLength))
        let contentRead = fread(&messageBytes, 1, Int(messageLength), stdin)
        
        guard contentRead == messageLength else {
            return nil
        }
        
        let messageData = Data(messageBytes)
        
        do {
            let json = try JSONSerialization.jsonObject(with: messageData)
            return json as? [String: Any]
        } catch {
            logError("Failed to parse JSON: \\(error)")
            return nil
        }
    }
    
    private func sendMessage(_ message: [String: Any]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: message)
            
            // Write 4-byte message length
            var length = UInt32(data.count)
            fwrite(&length, 4, 1, stdout)
            
            // Write message content
            data.withUnsafeBytes { bytes in
                fwrite(bytes.baseAddress, 1, data.count, stdout)
            }
            
            fflush(stdout)
        } catch {
            logError("Failed to send message: \\(error)")
        }
    }
    
    private func handleMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else {
            sendError("Missing message type")
            return
        }
        
        switch type {
        case "ping":
            sendMessage(["type": "pong"])
            
        case "download":
            handleDownloadRequest(message)
            
        case "batch":
            handleBatchDownload(message)
            
        case "detect_media":
            handleMediaDetection(message)
            
        case "get_status":
            handleStatusRequest(message)
            
        case "exit":
            shouldExit = true
            sendMessage(["type": "goodbye"])
            
        default:
            sendError("Unknown message type: \\(type)")
        }
    }
    
    private func handleDownloadRequest(_ message: [String: Any]) {
        guard let url = message["url"] as? String else {
            sendError("Missing URL in download request")
            return
        }
        
        // Forward to SwiftFetchDaemon via XPC
        let xpcMessage: [String: Any] = [
            "command": "add_download",
            "url": url,
            "filename": message["filename"] as? String,
            "referrer": message["referrer"] as? String,
            "cookies": message["cookies"] as? String,
            "userAgent": message["userAgent"] as? String,
            "headers": message["headers"] as? [String: String] ?? [:],
            "tabUrl": message["tabUrl"] as? String,
            "tabTitle": message["tabTitle"] as? String
        ]
        
        // In production, this would send to XPC service
        // For now, send mock response
        sendMessage([
            "type": "download_started",
            "taskId": UUID().uuidString,
            "message": "Download queued: \\(url)"
        ])
    }
    
    private func handleBatchDownload(_ message: [String: Any]) {
        guard let urls = message["urls"] as? [String] else {
            sendError("Missing URLs in batch request")
            return
        }
        
        var taskIds: [String] = []
        for url in urls {
            taskIds.append(UUID().uuidString)
        }
        
        sendMessage([
            "type": "batch_started",
            "taskIds": taskIds,
            "message": "Queued \\(urls.count) downloads"
        ])
    }
    
    private func handleMediaDetection(_ message: [String: Any]) {
        guard let tabId = message["tabId"] as? Int,
              let manifests = message["manifests"] as? [[String: Any]] else {
            sendError("Invalid media detection request")
            return
        }
        
        sendMessage([
            "type": "media_detected",
            "tabId": tabId,
            "count": manifests.count
        ])
    }
    
    private func handleStatusRequest(_ message: [String: Any]) {
        // Return mock status
        sendMessage([
            "type": "status",
            "tasks": [
                [
                    "id": "task-1",
                    "url": "https://example.com/file.zip",
                    "progress": 0.45,
                    "speed": 1_234_567,
                    "status": "active"
                ]
            ]
        ])
    }
    
    private func sendError(_ error: String) {
        sendMessage([
            "type": "error",
            "message": error
        ])
    }
    
    private func logError(_ message: String) {
        // Log to file since stderr might not be available
        let logPath = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/SwiftFetch/native-host.log")
        
        try? FileManager.default.createDirectory(
            at: logPath.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logEntry = "[\\(timestamp)] ERROR: \\(message)\\n"
        
        if let data = logEntry.data(using: .utf8) {
            try? data.append(to: logPath)
        }
    }
}

// Extension for appending data to file
extension Data {
    func append(to url: URL) throws {
        if let fileHandle = FileHandle(forWritingAtPath: url.path) {
            defer { fileHandle.closeFile() }
            fileHandle.seekToEndOfFile()
            fileHandle.write(self)
        } else {
            try write(to: url)
        }
    }
}

// Main entry point
let host = NativeMessageHost()
host.run()