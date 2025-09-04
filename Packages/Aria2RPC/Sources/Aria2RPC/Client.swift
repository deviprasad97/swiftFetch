import Foundation

public actor Aria2Client {
    private let session: URLSession
    private let endpoint: URL
    private var requestId = 0
    private let secret: String?
    
    public init(
        endpoint: URL = URL(string: "http://localhost:6800/jsonrpc")!,
        secret: String? = nil
    ) {
        self.endpoint = endpoint
        self.secret = secret
        self.session = URLSession(configuration: .default)
    }
    
    // MARK: - Core RPC Methods
    
    public func addUri(
        urls: [String],
        options: [String: Any] = [:]
    ) async throws -> String {
        let params = secret != nil ? [secret!, urls, options] : [urls, options]
        let response = try await sendRequest(method: "aria2.addUri", params: params)
        guard let gid = response["result"] as? String else {
            throw Aria2Error.invalidResponse
        }
        return gid
    }
    
    public func tellStatus(
        gid: String,
        keys: [String]? = nil
    ) async throws -> Aria2Status {
        var params: [Any] = secret != nil ? [secret!, gid] : [gid]
        if let keys = keys {
            params.append(keys)
        }
        
        let response = try await sendRequest(method: "aria2.tellStatus", params: params)
        guard let result = response["result"] as? [String: Any] else {
            throw Aria2Error.invalidResponse
        }
        
        return try Aria2Status(from: result)
    }
    
    public func pause(gid: String) async throws -> String {
        let params = secret != nil ? [secret!, gid] : [gid]
        let response = try await sendRequest(method: "aria2.pause", params: params)
        guard let result = response["result"] as? String else {
            throw Aria2Error.invalidResponse
        }
        return result
    }
    
    public func unpause(gid: String) async throws -> String {
        let params = secret != nil ? [secret!, gid] : [gid]
        let response = try await sendRequest(method: "aria2.unpause", params: params)
        guard let result = response["result"] as? String else {
            throw Aria2Error.invalidResponse
        }
        return result
    }
    
    public func remove(gid: String) async throws -> String {
        let params = secret != nil ? [secret!, gid] : [gid]
        let response = try await sendRequest(method: "aria2.remove", params: params)
        guard let result = response["result"] as? String else {
            throw Aria2Error.invalidResponse
        }
        return result
    }
    
    public func getGlobalStat() async throws -> GlobalStat {
        let params = secret != nil ? [secret!] : []
        let response = try await sendRequest(method: "aria2.getGlobalStat", params: params)
        guard let result = response["result"] as? [String: Any] else {
            throw Aria2Error.invalidResponse
        }
        return try GlobalStat(from: result)
    }
    
    public func changeGlobalOption(options: [String: Any]) async throws -> String {
        let params = secret != nil ? [secret!, options] : [options]
        let response = try await sendRequest(method: "aria2.changeGlobalOption", params: params)
        guard let result = response["result"] as? String else {
            throw Aria2Error.invalidResponse
        }
        return result
    }
    
    public func tellActive(keys: [String]? = nil) async throws -> [Aria2Status] {
        var params: [Any] = secret != nil ? [secret!] : []
        if let keys = keys {
            params.append(keys)
        }
        
        let response = try await sendRequest(method: "aria2.tellActive", params: params)
        guard let results = response["result"] as? [[String: Any]] else {
            throw Aria2Error.invalidResponse
        }
        
        return try results.map { try Aria2Status(from: $0) }
    }
    
    public func shutdown() async throws -> String {
        let params = secret != nil ? [secret!] : []
        let response = try await sendRequest(method: "aria2.shutdown", params: params)
        guard let result = response["result"] as? String else {
            throw Aria2Error.invalidResponse
        }
        return result
    }
    
    // MARK: - Private Methods
    
    private func sendRequest(method: String, params: [Any]) async throws -> [String: Any] {
        requestId += 1
        
        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": String(requestId),
            "method": method,
            "params": params
        ]
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw Aria2Error.networkError
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Aria2Error.invalidResponse
        }
        
        if let error = json["error"] as? [String: Any] {
            let code = error["code"] as? Int ?? -1
            let message = error["message"] as? String ?? "Unknown error"
            throw Aria2Error.rpcError(code: code, message: message)
        }
        
        return json
    }
}

// MARK: - Models

public struct Aria2Status {
    public let gid: String
    public let status: String
    public let totalLength: Int64
    public let completedLength: Int64
    public let downloadSpeed: Int64
    public let uploadSpeed: Int64
    public let connections: Int
    public let numPieces: Int?
    public let pieceLength: Int64?
    public let errorCode: String?
    public let errorMessage: String?
    public let files: [Aria2File]
    
    init(from dict: [String: Any]) throws {
        guard let gid = dict["gid"] as? String,
              let status = dict["status"] as? String else {
            throw Aria2Error.invalidResponse
        }
        
        self.gid = gid
        self.status = status
        self.totalLength = Int64(dict["totalLength"] as? String ?? "0") ?? 0
        self.completedLength = Int64(dict["completedLength"] as? String ?? "0") ?? 0
        self.downloadSpeed = Int64(dict["downloadSpeed"] as? String ?? "0") ?? 0
        self.uploadSpeed = Int64(dict["uploadSpeed"] as? String ?? "0") ?? 0
        self.connections = Int(dict["connections"] as? String ?? "0") ?? 0
        self.numPieces = Int(dict["numPieces"] as? String ?? "")
        self.pieceLength = Int64(dict["pieceLength"] as? String ?? "")
        self.errorCode = dict["errorCode"] as? String
        self.errorMessage = dict["errorMessage"] as? String
        
        if let filesArray = dict["files"] as? [[String: Any]] {
            self.files = filesArray.compactMap { try? Aria2File(from: $0) }
        } else {
            self.files = []
        }
    }
}

public struct Aria2File {
    public let index: Int
    public let path: String
    public let length: Int64
    public let completedLength: Int64
    public let selected: Bool
    public let uris: [Aria2Uri]
    
    init(from dict: [String: Any]) throws {
        self.index = Int(dict["index"] as? String ?? "0") ?? 0
        self.path = dict["path"] as? String ?? ""
        self.length = Int64(dict["length"] as? String ?? "0") ?? 0
        self.completedLength = Int64(dict["completedLength"] as? String ?? "0") ?? 0
        self.selected = (dict["selected"] as? String) == "true"
        
        if let urisArray = dict["uris"] as? [[String: Any]] {
            self.uris = urisArray.compactMap { try? Aria2Uri(from: $0) }
        } else {
            self.uris = []
        }
    }
}

public struct Aria2Uri {
    public let uri: String
    public let status: String
    
    init(from dict: [String: Any]) throws {
        self.uri = dict["uri"] as? String ?? ""
        self.status = dict["status"] as? String ?? ""
    }
}

public struct GlobalStat {
    public let downloadSpeed: Int64
    public let uploadSpeed: Int64
    public let numActive: Int
    public let numWaiting: Int
    public let numStopped: Int
    public let numStoppedTotal: Int
    
    init(from dict: [String: Any]) throws {
        self.downloadSpeed = Int64(dict["downloadSpeed"] as? String ?? "0") ?? 0
        self.uploadSpeed = Int64(dict["uploadSpeed"] as? String ?? "0") ?? 0
        self.numActive = Int(dict["numActive"] as? String ?? "0") ?? 0
        self.numWaiting = Int(dict["numWaiting"] as? String ?? "0") ?? 0
        self.numStopped = Int(dict["numStopped"] as? String ?? "0") ?? 0
        self.numStoppedTotal = Int(dict["numStoppedTotal"] as? String ?? "0") ?? 0
    }
}

// MARK: - Errors

public enum Aria2Error: Error {
    case invalidResponse
    case networkError
    case rpcError(code: Int, message: String)
    case connectionFailed
}