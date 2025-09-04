import Foundation
import AppKit

class NativeMessagingHandler {
    static let shared = NativeMessagingHandler()
    
    private init() {}
    
    // Check if app was launched for native messaging
    static func isNativeMessagingMode() -> Bool {
        // Check if stdin is a pipe (native messaging mode)
        var statbuf = stat()
        fstat(STDIN_FILENO, &statbuf)
        return (statbuf.st_mode & S_IFMT) == S_IFIFO
    }
    
    // Handle native messaging communication
    func startNativeMessaging() {
        // Set stdin to binary mode
        setbuf(stdin, nil)
        setbuf(stdout, nil)
        
        while true {
            guard let message = readMessage() else {
                break
            }
            
            handleMessage(message)
        }
    }
    
    // Read message from Chrome
    private func readMessage() -> [String: Any]? {
        // Read 4-byte message length
        var lengthBytes = [UInt8](repeating: 0, count: 4)
        let lengthRead = read(STDIN_FILENO, &lengthBytes, 4)
        
        if lengthRead != 4 {
            return nil
        }
        
        // Convert to length (little-endian)
        let length = Int(lengthBytes[0]) |
                    (Int(lengthBytes[1]) << 8) |
                    (Int(lengthBytes[2]) << 16) |
                    (Int(lengthBytes[3]) << 24)
        
        if length <= 0 || length > 1024 * 1024 {
            return nil
        }
        
        // Read message
        var messageBytes = [UInt8](repeating: 0, count: length)
        let messageRead = read(STDIN_FILENO, &messageBytes, length)
        
        if messageRead != length {
            return nil
        }
        
        // Parse JSON
        let data = Data(messageBytes)
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return json
            }
        } catch {
            logError("Failed to parse JSON: \(error)")
        }
        
        return nil
    }
    
    // Send message to Chrome
    private func sendMessage(_ message: [String: Any]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: message)
            let length = data.count
            
            // Write 4-byte length (little-endian)
            var lengthBytes = [UInt8](repeating: 0, count: 4)
            lengthBytes[0] = UInt8(length & 0xFF)
            lengthBytes[1] = UInt8((length >> 8) & 0xFF)
            lengthBytes[2] = UInt8((length >> 16) & 0xFF)
            lengthBytes[3] = UInt8((length >> 24) & 0xFF)
            
            _ = write(STDOUT_FILENO, lengthBytes, 4)
            _ = data.withUnsafeBytes { bytes in
                write(STDOUT_FILENO, bytes.baseAddress!, length)
            }
            
            fflush(stdout)
        } catch {
            logError("Failed to send message: \(error)")
        }
    }
    
    // Handle incoming message
    private func handleMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else {
            sendMessage(["type": "error", "message": "Missing message type"])
            return
        }
        
        switch type {
        case "ping":
            // Respond to ping
            sendMessage([
                "type": "pong",
                "status": "connected",
                "version": "1.0.0"
            ])
            
        case "download":
            // Handle download request
            if let url = message["url"] as? String {
                handleDownload(url: url, message: message)
            } else {
                sendMessage([
                    "type": "error",
                    "message": "Missing URL"
                ])
            }
            
        case "status", "get_status":
            // Return app status
            sendMessage([
                "type": "status_response",
                "connected": true,
                "app_running": true,
                "downloads_active": 0
            ])
            
        case "get_settings":
            // Return settings
            sendMessage([
                "type": "settings",
                "interceptDownloads": true,
                "detectMedia": true,
                "notifications": true
            ])
            
        case "shouldIntercept":
            // Check if should intercept download
            sendMessage([
                "type": "intercept_response",
                "shouldIntercept": true
            ])
            
        default:
            // Log unknown message type but don't error
            logError("Unknown message type: \(type)")
            sendMessage([
                "type": "response",
                "success": true
            ])
        }
    }
    
    // Handle download request from extension
    private func handleDownload(url: String, message: [String: Any]) {
        logError("Received download request: \(url)")
        
        // Check if main app is running
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
        let appBundleID = "com.swiftfetch.app"
        
        var mainAppRunning = false
        for app in runningApps {
            if app.bundleIdentifier == appBundleID {
                mainAppRunning = true
                break
            }
        }
        
        logError("Main app running: \(mainAppRunning)")
        
        // Launch or activate the main app with the download URL
        if let downloadURL = URL(string: url) {
            // Create a custom URL scheme for SwiftFetch
            var components = URLComponents()
            components.scheme = "swiftfetch"
            components.host = "download"
            components.queryItems = [
                URLQueryItem(name: "url", value: url),
                URLQueryItem(name: "filename", value: message["filename"] as? String),
                URLQueryItem(name: "referrer", value: message["referrer"] as? String),
                URLQueryItem(name: "cookies", value: message["cookies"] as? String),
                URLQueryItem(name: "userAgent", value: message["userAgent"] as? String)
            ]
            
            if let swiftfetchURL = components.url {
                logError("Opening SwiftFetch URL: \(swiftfetchURL)")
                
                // Open the URL which will launch/activate the main app
                NSWorkspace.shared.open(swiftfetchURL)
                
                // Send success response
                sendMessage([
                    "type": "download_response",
                    "success": true,
                    "url": url
                ])
            } else {
                sendMessage([
                    "type": "download_response",
                    "success": false,
                    "error": "Failed to create SwiftFetch URL"
                ])
            }
        } else {
            sendMessage([
                "type": "download_response",
                "success": false,
                "error": "Invalid URL"
            ])
        }
    }
    
    // Build headers from extension data
    private func buildHeaders(referrer: String?, cookies: String?, userAgent: String?) -> [String: String] {
        var headers: [String: String] = [:]
        
        if let referrer = referrer {
            headers["Referer"] = referrer
        }
        
        if let cookies = cookies {
            headers["Cookie"] = cookies
        }
        
        if let userAgent = userAgent {
            headers["User-Agent"] = userAgent
        }
        
        return headers.isEmpty ? [:] : headers
    }
    
    private func logError(_ message: String) {
        #if DEBUG
        let logPath = "/tmp/swiftfetch_native.log"
        if let handle = FileHandle(forWritingAtPath: logPath) {
            handle.seekToEndOfFile()
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let log = "[\(timestamp)] ERROR: \(message)\n"
            handle.write(log.data(using: .utf8) ?? Data())
            handle.closeFile()
        } else {
            FileManager.default.createFile(atPath: logPath, contents: nil)
        }
        #endif
    }
}

// Native messaging download request structure
struct NativeDownloadRequest: Codable {
    let url: String
    let filename: String?
    let referrer: String?
    let cookies: String?
    let userAgent: String?
}