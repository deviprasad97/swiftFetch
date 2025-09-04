import Foundation
import Combine

@MainActor
class BrowserBridge: ObservableObject {
    @Published var isConnected = false
    @Published var detectedMedia: [MediaItem] = []
    @Published var recentRequests: [BrowserDownloadRequest] = []
    
    var onDownloadRequest: ((BrowserDownloadRequest) -> Void)?
    var onMediaDetected: ((MediaItem) -> Void)?
    
    private var nativeMessagePort: FileHandle?
    private var messageBuffer = Data()
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    init() {
        setupNativeMessaging()
    }
    
    private func setupNativeMessaging() {
        // This would be launched by the browser extension
        // For now, we'll simulate the connection
        
        // In production, this would listen on stdin for messages from browser
        // FileHandle.standardInput for reading
        // FileHandle.standardOutput for writing
    }
    
    func handleMessage(from browser: Data) {
        do {
            let message = try decoder.decode(BrowserMessage.self, from: browser)
            
            switch message.type {
            case .download:
                handleDownloadMessage(message)
            case .batch:
                handleBatchMessage(message)
            case .detectMedia:
                handleMediaDetection(message)
            case .ping:
                sendPong()
            case .getStatus:
                sendStatus()
            }
        } catch {
            print("Failed to decode browser message: \(error)")
        }
    }
    
    private func handleDownloadMessage(_ message: BrowserMessage) {
        guard let url = message.url,
              let request = createDownloadRequest(from: message) else {
            sendError("Invalid download request")
            return
        }
        
        recentRequests.append(request)
        onDownloadRequest?(request)
        
        sendResponse(BrowserResponse(
            type: .downloadStarted,
            taskId: UUID().uuidString,
            message: "Download queued: \(url)"
        ))
    }
    
    private func handleBatchMessage(_ message: BrowserMessage) {
        guard let urls = message.urls else {
            sendError("Missing URLs in batch request")
            return
        }
        
        var taskIds: [String] = []
        
        for urlString in urls {
            if let url = URL(string: urlString) {
                let request = BrowserDownloadRequest(
                    url: urlString,
                    filename: url.lastPathComponent,
                    referrer: message.tabUrl,
                    cookies: message.cookies,
                    userAgent: message.userAgent,
                    tabUrl: message.tabUrl,
                    tabTitle: message.tabTitle
                )
                
                recentRequests.append(request)
                onDownloadRequest?(request)
                
                taskIds.append(UUID().uuidString)
            }
        }
        
        sendResponse(BrowserResponse(
            type: .batchStarted,
            taskIds: taskIds,
            message: "Queued \(taskIds.count) downloads"
        ))
    }
    
    private func handleMediaDetection(_ message: BrowserMessage) {
        guard let manifests = message.manifests else {
            sendError("Invalid media detection data")
            return
        }
        
        for manifest in manifests {
            let mediaItem = MediaItem(
                id: UUID().uuidString,
                url: manifest.url,
                type: manifest.type,
                format: manifest.format,
                title: message.tabTitle,
                thumbnailURL: manifest.thumbnail,
                duration: manifest.duration,
                quality: manifest.quality,
                fileSize: manifest.fileSize
            )
            
            detectedMedia.append(mediaItem)
            onMediaDetected?(mediaItem)
        }
        
        sendResponse(BrowserResponse(
            type: .mediaDetected,
            count: manifests.count
        ))
    }
    
    private func sendPong() {
        sendResponse(BrowserResponse(type: .pong))
        isConnected = true
    }
    
    private func sendStatus() {
        // Get current download status and send to browser
        sendResponse(BrowserResponse(
            type: .status,
            tasks: [] // Would be populated with actual tasks
        ))
    }
    
    private func sendError(_ message: String) {
        sendResponse(BrowserResponse(
            type: .error,
            message: message
        ))
    }
    
    private func sendResponse(_ response: BrowserResponse) {
        do {
            let data = try encoder.encode(response)
            sendToExtension(data)
        } catch {
            print("Failed to encode response: \(error)")
        }
    }
    
    private func sendToExtension(_ data: Data) {
        // In production, this would write to stdout with length prefix
        // For native messaging protocol
        
        var length = UInt32(data.count).littleEndian
        let lengthData = Data(bytes: &length, count: 4)
        
        // Write to stdout (would be FileHandle.standardOutput in production)
        // fileHandle.write(lengthData)
        // fileHandle.write(data)
    }
    
    private func createDownloadRequest(from message: BrowserMessage) -> BrowserDownloadRequest? {
        guard let url = message.url else { return nil }
        
        return BrowserDownloadRequest(
            url: url,
            filename: message.filename,
            referrer: message.referrer,
            cookies: message.cookies,
            userAgent: message.userAgent,
            tabUrl: message.tabUrl,
            tabTitle: message.tabTitle
        )
    }
    
    // MARK: - Public Methods
    
    func downloadMedia(_ item: MediaItem) {
        let request = BrowserDownloadRequest(
            url: item.url,
            filename: item.suggestedFilename,
            referrer: nil,
            cookies: nil,
            userAgent: nil,
            tabUrl: nil,
            tabTitle: item.title
        )
        
        onDownloadRequest?(request)
    }
    
    func clearDetectedMedia() {
        detectedMedia.removeAll()
    }
    
    func testConnection() {
        sendResponse(BrowserResponse(type: .ping))
    }
}

// MARK: - Message Types

struct BrowserMessage: Codable {
    enum MessageType: String, Codable {
        case download
        case batch
        case detectMedia = "detect_media"
        case ping
        case getStatus = "get_status"
    }
    
    let type: MessageType
    let url: String?
    let urls: [String]?
    let filename: String?
    let referrer: String?
    let cookies: String?
    let userAgent: String?
    let headers: [String: String]?
    let tabUrl: String?
    let tabTitle: String?
    let tabId: Int?
    let manifests: [MediaManifest]?
}

struct MediaManifest: Codable {
    let url: String
    let type: String
    let format: String
    let thumbnail: String?
    let duration: Int?
    let quality: String?
    let fileSize: Int64?
}

struct BrowserResponse: Codable {
    enum ResponseType: String, Codable {
        case pong
        case downloadStarted = "download_started"
        case batchStarted = "batch_started"
        case downloadExists = "download_exists"
        case mediaDetected = "media_detected"
        case status
        case error
        case ping
    }
    
    let type: ResponseType
    let taskId: String?
    let taskIds: [String]?
    let message: String?
    let tasks: [TaskStatusResponse]?
    let count: Int?
    
    init(type: ResponseType, 
         taskId: String? = nil,
         taskIds: [String]? = nil,
         message: String? = nil,
         tasks: [TaskStatusResponse]? = nil,
         count: Int? = nil) {
        self.type = type
        self.taskId = taskId
        self.taskIds = taskIds
        self.message = message
        self.tasks = tasks
        self.count = count
    }
}

struct TaskStatusResponse: Codable {
    let id: String
    let url: String
    let progress: Double
    let speed: Int64
    let status: String
}

// MARK: - Media Item

struct MediaItem: Identifiable {
    let id: String
    let url: String
    let type: String  // hls, dash, direct
    let format: String
    let title: String?
    let thumbnailURL: String?
    let duration: Int?
    let quality: String?
    let fileSize: Int64?
    
    var displayName: String {
        if let title = title, !title.isEmpty {
            return title
        }
        return URL(string: url)?.lastPathComponent ?? "Media"
    }
    
    var formattedDuration: String? {
        guard let duration = duration else { return nil }
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var formattedFileSize: String? {
        guard let size = fileSize else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: size)
    }
    
    var suggestedFilename: String {
        let base = displayName.replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
        
        let ext: String
        switch format.lowercased() {
        case "hls":
            ext = "mp4"
        case "dash":
            ext = "mp4"
        case "mp4", "webm", "mkv", "avi":
            ext = format.lowercased()
        default:
            ext = "mp4"
        }
        
        return "\(base).\(ext)"
    }
}

// MARK: - Extension Status

struct ExtensionStatus {
    let browser: String
    let version: String?
    let isConnected: Bool
    let lastSeen: Date?
    
    var displayStatus: String {
        if isConnected {
            return "Connected"
        } else if let lastSeen = lastSeen {
            let formatter = RelativeDateTimeFormatter()
            return "Last seen \(formatter.localizedString(for: lastSeen, relativeTo: Date()))"
        } else {
            return "Not installed"
        }
    }
}