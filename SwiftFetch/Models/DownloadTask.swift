import Foundation

public struct DownloadTask: Identifiable, Codable {
    public let id: String
    public var gid: String?
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
    public var downloadSpeed: Int64 = 0
    public var uploadSpeed: Int64 = 0
    public var eta: TimeInterval?
    public var speedHistory: [SpeedDataPoint] = []
    
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
    case complete  // aria2 uses "complete"
    case completed // our app uses "completed"
    case error
    case removed
    
    // Map aria2 status to our status
    public init(aria2Status: String) {
        switch aria2Status {
        case "complete":
            self = .completed
        case "waiting":
            self = .waiting
        case "active":
            self = .active
        case "paused":
            self = .paused
        case "error":
            self = .error
        case "removed":
            self = .removed
        default:
            self = .pending
        }
    }
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

public struct Category: Identifiable, Codable, Equatable, Hashable {
    public let id: Int
    public var name: String
    public var destination: URL
    public var color: String
    public var icon: String
    public var namingTemplate: String?
    public var postActions: [PostAction]
    
    public static func == (lhs: Category, rhs: Category) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
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

public enum PostAction: Codable, Equatable, Hashable {
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

public struct DownloadSchedule: Codable {
    public let date: Date
    public let type: ScheduleType
    
    public init(date: Date, type: ScheduleType = .once) {
        self.date = date
        self.type = type
    }
}

public enum ScheduleType: String, Codable {
    case once
    case daily
    case weekly
}

public struct SpeedDataPoint: Codable {
    public let timestamp: Date
    public let speed: Int64
    
    public init(timestamp: Date = Date(), speed: Int64) {
        self.timestamp = timestamp
        self.speed = speed
    }
}