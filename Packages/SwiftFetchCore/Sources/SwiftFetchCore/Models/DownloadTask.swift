import Foundation

public struct DownloadTask: Identifiable, Codable {
    public let id: String
    public let gid: String?  // aria2 GID
    public let url: URL
    public var filename: String
    public var destination: URL
    public var size: Int64?
    public var completedSize: Int64
    public var status: TaskStatus
    public var errorMessage: String?
    public var segments: Int
    public var speedLimit: Int?
    public var category: Category?
    public var checksum: Checksum?
    public var createdAt: Date
    public var startedAt: Date?
    public var completedAt: Date?
    public var metadata: TaskMetadata
    
    public var progress: Double {
        guard let size = size, size > 0 else { return 0 }
        return Double(completedSize) / Double(size)
    }
    
    public var isActive: Bool {
        status == .active || status == .waiting
    }
    
    public init(
        id: String = UUID().uuidString,
        url: URL,
        filename: String? = nil,
        destination: URL,
        segments: Int = 8
    ) {
        self.id = id
        self.gid = nil
        self.url = url
        self.filename = filename ?? url.lastPathComponent
        self.destination = destination
        self.size = nil
        self.completedSize = 0
        self.status = .pending
        self.errorMessage = nil
        self.segments = segments
        self.speedLimit = nil
        self.category = nil
        self.checksum = nil
        self.createdAt = Date()
        self.startedAt = nil
        self.completedAt = nil
        self.metadata = TaskMetadata()
    }
}

public enum TaskStatus: String, Codable {
    case pending
    case waiting
    case active
    case paused
    case completed
    case error
    case removed
}

public struct TaskMetadata: Codable {
    public var headers: [String: String]
    public var cookies: String?
    public var referrer: String?
    public var userAgent: String?
    public var tabUrl: String?
    public var tabTitle: String?
    
    public init(
        headers: [String: String] = [:],
        cookies: String? = nil,
        referrer: String? = nil,
        userAgent: String? = nil,
        tabUrl: String? = nil,
        tabTitle: String? = nil
    ) {
        self.headers = headers
        self.cookies = cookies
        self.referrer = referrer
        self.userAgent = userAgent
        self.tabUrl = tabUrl
        self.tabTitle = tabTitle
    }
}

public struct Category: Identifiable, Codable {
    public let id: Int
    public var name: String
    public var destination: URL
    public var color: String
    public var icon: String
    public var namingTemplate: String?
    public var postActions: [PostAction]
    
    public init(
        id: Int,
        name: String,
        destination: URL,
        color: String = "blue",
        icon: String = "folder"
    ) {
        self.id = id
        self.name = name
        self.destination = destination
        self.color = color
        self.icon = icon
        self.namingTemplate = nil
        self.postActions = []
    }
}

public enum PostAction: Codable {
    case openInFinder
    case unzip
    case verifyChecksum
    case runScript(String)
    case scanWithAntivirus
}

public struct Checksum: Codable {
    public let type: ChecksumType
    public let value: String
    
    public init(type: ChecksumType, value: String) {
        self.type = type
        self.value = value
    }
}

public enum ChecksumType: String, Codable {
    case md5 = "MD5"
    case sha1 = "SHA-1"
    case sha256 = "SHA-256"
    case sha512 = "SHA-512"
}