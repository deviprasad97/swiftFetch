import Foundation

actor SimpleStorageManager {
    private let documentsDirectory: URL
    private let tasksFile: URL
    private var cachedTasks: [DownloadTask] = []
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    init() {
        // Use Documents directory which is more reliable in sandboxed apps
        let fileManager = FileManager.default
        if let containerURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            self.documentsDirectory = containerURL.appendingPathComponent("SwiftFetch", isDirectory: true)
        } else {
            // Fallback to temp directory
            self.documentsDirectory = fileManager.temporaryDirectory.appendingPathComponent("SwiftFetch", isDirectory: true)
        }
        
        // Create directory if needed
        try? fileManager.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)
        
        self.tasksFile = documentsDirectory.appendingPathComponent("downloads.json")
        
        // Setup encoder/decoder
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        
        print("📁 Storage directory: \(documentsDirectory.path)")
        
        // Load cached tasks
        loadTasksFromDisk()
    }
    
    private func loadTasksFromDisk() {
        guard FileManager.default.fileExists(atPath: tasksFile.path) else {
            print("📭 No existing downloads file found")
            return
        }
        
        do {
            let data = try Data(contentsOf: tasksFile)
            cachedTasks = try decoder.decode([DownloadTask].self, from: data)
            print("📖 Loaded \(cachedTasks.count) tasks from disk")
        } catch {
            print("❌ Failed to load tasks: \(error)")
            // Try to backup corrupted file
            let backupPath = tasksFile.appendingPathExtension("backup")
            try? FileManager.default.moveItem(at: tasksFile, to: backupPath)
            cachedTasks = []
        }
    }
    
    private func saveToDisk() {
        do {
            let data = try encoder.encode(cachedTasks)
            try data.write(to: tasksFile, options: .atomic)
            print("💾 Saved \(cachedTasks.count) tasks to disk")
        } catch {
            print("❌ Failed to save tasks: \(error)")
        }
    }
    
    func saveTask(_ task: DownloadTask) async {
        // Update or add task
        if let index = cachedTasks.firstIndex(where: { $0.id == task.id }) {
            cachedTasks[index] = task
            print("✅ Updated task: \(task.filename) (Status: \(task.status.rawValue))")
        } else {
            cachedTasks.append(task)
            print("✅ Added task: \(task.filename) (Status: \(task.status.rawValue))")
        }
        
        // Save to disk
        saveToDisk()
    }
    
    func loadTasks() async -> [DownloadTask] {
        return cachedTasks
    }
    
    func deleteTask(_ taskId: String) async {
        cachedTasks.removeAll { $0.id == taskId }
        saveToDisk()
        print("🗑️ Deleted task: \(taskId)")
    }
    
    func deleteAllTasks() async {
        cachedTasks.removeAll()
        saveToDisk()
        print("🗑️ Deleted all tasks")
    }
    
    func getTask(by id: String) async -> DownloadTask? {
        return cachedTasks.first { $0.id == id }
    }
    
    // Category stubs for compatibility
    func saveCategory(_ category: Category) async {
        // Not implemented - can add later if needed
    }
    
    func loadCategories() async -> [Category] {
        return []
    }
    
    func saveSecurityBookmark(for url: URL) async {
        // Not implemented - can add later if needed
    }
    
    func loadSecurityBookmarks() async -> [URL] {
        return []
    }
}