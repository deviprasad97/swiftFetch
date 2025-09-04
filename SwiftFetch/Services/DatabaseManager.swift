import Foundation
import SQLite3

actor DatabaseManager {
    private var db: OpaquePointer?
    private let dbPath: String
    private let backupPath: String
    private let jsonBackupPath: String
    private var lastBackupTime = Date()
    private let dbQueue = DispatchQueue(label: "com.swiftfetch.db", attributes: .concurrent)
    
    init() {
        // Create database in Application Support
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let swiftFetchDir = appSupport.appendingPathComponent("SwiftFetch")
        
        // Create directory if needed with proper error handling
        do {
            try fileManager.createDirectory(at: swiftFetchDir, 
                                          withIntermediateDirectories: true, 
                                          attributes: nil)
            print("✅ Created/verified SwiftFetch directory at: \(swiftFetchDir.path)")
        } catch {
            print("❌ Failed to create SwiftFetch directory: \(error)")
            // Try alternative location in sandbox
            let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let altDir = documentsDir.appendingPathComponent("SwiftFetch")
            do {
                try fileManager.createDirectory(at: altDir, 
                                              withIntermediateDirectories: true, 
                                              attributes: nil)
                self.dbPath = altDir.appendingPathComponent("SwiftFetch.db").path
                self.backupPath = altDir.appendingPathComponent("SwiftFetch.db.backup").path
                self.jsonBackupPath = altDir.appendingPathComponent("downloads_backup.json").path
                print("✅ Using alternative location: \(self.dbPath)")
                Task {
                    await initializeDatabase()
                }
                return
            } catch {
                print("❌ Failed to create alternative directory: \(error)")
                fatalError("Cannot create database directory")
            }
        }
        
        self.dbPath = swiftFetchDir.appendingPathComponent("SwiftFetch.db").path
        self.backupPath = swiftFetchDir.appendingPathComponent("SwiftFetch.db.backup").path
        self.jsonBackupPath = swiftFetchDir.appendingPathComponent("downloads_backup.json").path
        print("📁 Database path: \(self.dbPath)")
        Task {
            await initializeDatabase()
        }
    }
    
    private func initializeDatabase() {
        // Try to backup existing data first
        if FileManager.default.fileExists(atPath: dbPath) {
            backupToJSON()
        }
        
        // Check for corruption
        if isDatabaseCorrupted() {
            print("⚠️ Database corruption detected, recovering...")
            recoverDatabase()
            return
        }
        
        // Open database with improved settings
        let result = sqlite3_open_v2(dbPath, &db, 
                                    SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, 
                                    nil)
        
        if result == SQLITE_OK {
            print("✅ Database opened successfully")
            
            // Enable WAL mode for better corruption resistance
            sqlite3_exec(db, "PRAGMA journal_mode=WAL", nil, nil, nil)
            sqlite3_exec(db, "PRAGMA synchronous=NORMAL", nil, nil, nil)
            sqlite3_exec(db, "PRAGMA busy_timeout=5000", nil, nil, nil)
            sqlite3_exec(db, "PRAGMA foreign_keys=ON", nil, nil, nil)
            sqlite3_exec(db, "PRAGMA temp_store=MEMORY", nil, nil, nil)
            sqlite3_exec(db, "PRAGMA cache_size=10000", nil, nil, nil)
            
            createTablesSync()
        } else {
            print("❌ Failed to open database: \(String(cString: sqlite3_errmsg(db)))")
            recoverDatabase()
        }
    }
    
    private func isDatabaseCorrupted() -> Bool {
        guard FileManager.default.fileExists(atPath: dbPath) else { return false }
        
        var tempDb: OpaquePointer?
        
        // Try to open the database
        guard sqlite3_open_v2(dbPath, &tempDb, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            return true
        }
        
        defer { sqlite3_close(tempDb) }
        
        // Quick integrity check
        let quickCheck = "PRAGMA quick_check(1)"
        var stmt: OpaquePointer?
        
        guard sqlite3_prepare_v2(tempDb, quickCheck, -1, &stmt, nil) == SQLITE_OK else {
            return true
        }
        
        defer { sqlite3_finalize(stmt) }
        
        var isCorrupted = false
        if sqlite3_step(stmt) == SQLITE_ROW {
            if let result = sqlite3_column_text(stmt, 0) {
                let resultString = String(cString: result)
                if resultString != "ok" {
                    print("Database corruption detected: \(resultString)")
                    isCorrupted = true
                }
            }
        }
        
        return isCorrupted
    }
    
    private func recoverDatabase() {
        print("🔧 Starting database recovery...")
        
        // Close existing connection properly
        if db != nil {
            // Use simple close - don't try to track statements
            sqlite3_close_v2(db)
            db = nil
        }
        
        // Wait a moment for filesystem to settle
        Thread.sleep(forTimeInterval: 0.2)
        
        // Backup corrupted database
        let corruptPath = dbPath + ".corrupt.\(Int(Date().timeIntervalSince1970))"
        if FileManager.default.fileExists(atPath: dbPath) {
            try? FileManager.default.moveItem(atPath: dbPath, toPath: corruptPath)
        }
        
        // Also remove WAL files if they exist
        let walPath = dbPath + "-wal"
        let shmPath = dbPath + "-shm"
        if FileManager.default.fileExists(atPath: walPath) {
            try? FileManager.default.removeItem(atPath: walPath)
        }
        if FileManager.default.fileExists(atPath: shmPath) {
            try? FileManager.default.removeItem(atPath: shmPath)
        }
        
        // Create new database
        guard sqlite3_open_v2(dbPath, &db, 
                            SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, 
                            nil) == SQLITE_OK else {
            print("❌ Failed to create new database")
            return
        }
        
        // Setup new database with WAL mode
        sqlite3_exec(db, "PRAGMA journal_mode=WAL", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA synchronous=NORMAL", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA busy_timeout=5000", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA foreign_keys=ON", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA temp_store=MEMORY", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA cache_size=10000", nil, nil, nil)
        
        createTablesSync()
        
        // Restore from JSON backup if available
        restoreFromJSON()
        
        print("✅ Database recovery complete")
    }
    
    private func backupToJSON() {
        let tasks = getAllTasksForBackup()
        
        guard !tasks.isEmpty else { return }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        if let data = try? encoder.encode(tasks) {
            try? data.write(to: URL(fileURLWithPath: jsonBackupPath))
            lastBackupTime = Date()
            print("💾 Backed up \(tasks.count) tasks to JSON")
        }
    }
    
    private func restoreFromJSON() {
        guard FileManager.default.fileExists(atPath: jsonBackupPath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: jsonBackupPath)) else {
            print("📭 No JSON backup found")
            return
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let tasks = try? decoder.decode([DownloadTask].self, from: data) else {
            print("❌ Failed to decode JSON backup")
            return
        }
        
        print("📥 Restoring \(tasks.count) tasks from backup...")
        for task in tasks {
            saveTaskInternal(task)
        }
    }
    
    private func getAllTasksForBackup() -> [DownloadTask] {
        guard db != nil else { return [] }
        
        let query = """
            SELECT id, gid, url, filename, destination, size, completed_size, 
                   status, error_message, segments, speed_limit, category_id,
                   checksum_type, checksum_value, created_at, started_at, 
                   completed_at, metadata
            FROM downloads
            WHERE status != 'removed'
            ORDER BY created_at DESC
        """
        
        var tasks: [DownloadTask] = []
        var stmt: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            return tasks
        }
        
        defer { sqlite3_finalize(stmt) }
        
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let task = taskFromRow(stmt) {
                tasks.append(task)
            }
        }
        
        return tasks
    }
    
    private func createTablesSync() {
        // Create downloads table without CHECK constraint
        let createDownloadsTable = """
            CREATE TABLE IF NOT EXISTS downloads (
                id TEXT PRIMARY KEY,
                gid TEXT UNIQUE,
                url TEXT NOT NULL,
                filename TEXT,
                destination TEXT NOT NULL,
                size INTEGER,
                completed_size INTEGER DEFAULT 0,
                status TEXT,
                error_message TEXT,
                segments INTEGER DEFAULT 1,
                speed_limit INTEGER,
                category_id INTEGER,
                checksum_type TEXT,
                checksum_value TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                started_at TIMESTAMP,
                completed_at TIMESTAMP,
                metadata TEXT,
                FOREIGN KEY (category_id) REFERENCES categories(id)
            );
        """
        
        if sqlite3_exec(db, createDownloadsTable, nil, nil, nil) == SQLITE_OK {
            print("✅ Downloads table created/verified")
        } else {
            print("❌ Failed to create downloads table: \(String(cString: sqlite3_errmsg(db)))")
        }
        
        // Create other tables
        createOtherTables()
    }
    
    private func createOtherTables() {
        let createCategoriesTable = """
            CREATE TABLE IF NOT EXISTS categories (
                id INTEGER PRIMARY KEY,
                name TEXT UNIQUE NOT NULL,
                destination TEXT NOT NULL,
                color TEXT,
                icon TEXT,
                naming_template TEXT,
                post_actions TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        """
        
        let createRulesTable = """
            CREATE TABLE IF NOT EXISTS rules (
                id INTEGER PRIMARY KEY,
                name TEXT NOT NULL,
                enabled BOOLEAN DEFAULT 1,
                priority INTEGER DEFAULT 0,
                conditions TEXT NOT NULL,
                actions TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        """
        
        let createSchedulesTable = """
            CREATE TABLE IF NOT EXISTS schedules (
                id INTEGER PRIMARY KEY,
                download_id TEXT,
                type TEXT CHECK(type IN ('once','daily','weekly','cron')),
                spec TEXT NOT NULL,
                next_run TIMESTAMP,
                enabled BOOLEAN DEFAULT 1,
                FOREIGN KEY (download_id) REFERENCES downloads(id)
            );
        """
        
        let createHistoryTable = """
            CREATE TABLE IF NOT EXISTS history (
                id INTEGER PRIMARY KEY,
                download_id TEXT,
                event_type TEXT NOT NULL,
                event_data TEXT,
                timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (download_id) REFERENCES downloads(id)
            );
        """
        
        let createBookmarksTable = """
            CREATE TABLE IF NOT EXISTS security_bookmarks (
                id INTEGER PRIMARY KEY,
                path TEXT UNIQUE NOT NULL,
                bookmark_data BLOB NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        """
        
        // Create indexes
        let indexes = [
            "CREATE INDEX IF NOT EXISTS idx_downloads_status ON downloads(status);",
            "CREATE INDEX IF NOT EXISTS idx_downloads_created ON downloads(created_at);",
            "CREATE INDEX IF NOT EXISTS idx_rules_priority ON rules(priority, enabled);",
            "CREATE INDEX IF NOT EXISTS idx_history_download ON history(download_id, timestamp);"
        ]
        
        // Execute all CREATE TABLE statements
        for (name, statement) in [
            ("categories", createCategoriesTable),
            ("rules", createRulesTable),
            ("schedules", createSchedulesTable),
            ("history", createHistoryTable),
            ("security_bookmarks", createBookmarksTable)
        ] {
            if sqlite3_exec(db, statement, nil, nil, nil) == SQLITE_OK {
                print("✅ Table '\(name)' created/verified")
            } else {
                print("❌ Failed to create table '\(name)': \(String(cString: sqlite3_errmsg(db)))")
            }
        }
        
        // Create indexes
        for index in indexes {
            sqlite3_exec(db, index, nil, nil, nil)
        }
    }
    
    // MARK: - Task Operations
    
    func saveTask(_ task: DownloadTask) async {
        // Periodic backup (every 5 minutes)
        if Date().timeIntervalSince(lastBackupTime) > 300 {
            backupToJSON()
        }
        
        // Try to save with recovery on failure
        if !saveTaskInternal(task) {
            // If save failed, try recovery once
            print("⚠️ Save failed, attempting recovery...")
            recoverDatabase()
            saveTaskInternal(task)
        }
    }
    
    @discardableResult
    private func saveTaskInternal(_ task: DownloadTask) -> Bool {
        guard db != nil else {
            print("❌ Database not available")
            return false
        }
        
        let metadata = try? JSONEncoder().encode(task.metadata)
        let metadataString = metadata.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        
        let query = """
            INSERT OR REPLACE INTO downloads 
            (id, gid, url, filename, destination, size, completed_size, status, 
             error_message, segments, speed_limit, category_id, checksum_type, 
             checksum_value, created_at, started_at, completed_at, metadata)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            let error = String(cString: sqlite3_errmsg(db))
            print("Failed to prepare statement: \(error)")
            return false
        }
        
        sqlite3_bind_text(stmt, 1, task.id, -1, nil)
        sqlite3_bind_text(stmt, 2, task.gid, -1, nil)
        sqlite3_bind_text(stmt, 3, task.url.absoluteString, -1, nil)
        sqlite3_bind_text(stmt, 4, task.filename, -1, nil)
        sqlite3_bind_text(stmt, 5, task.destination.path, -1, nil)
        
        if let size = task.size {
            sqlite3_bind_int64(stmt, 6, size)
        } else {
            sqlite3_bind_null(stmt, 6)
        }
        
        sqlite3_bind_int64(stmt, 7, task.completedSize)
        sqlite3_bind_text(stmt, 8, task.status.rawValue, -1, nil)
        sqlite3_bind_text(stmt, 9, task.errorMessage, -1, nil)
        sqlite3_bind_int(stmt, 10, Int32(task.segments))
        
        if let speedLimit = task.speedLimit {
            sqlite3_bind_int(stmt, 11, Int32(speedLimit))
        } else {
            sqlite3_bind_null(stmt, 11)
        }
        
        if let categoryId = task.category?.id {
            sqlite3_bind_int(stmt, 12, Int32(categoryId))
        } else {
            sqlite3_bind_null(stmt, 12)
        }
        
        sqlite3_bind_text(stmt, 13, task.checksum?.type.rawValue, -1, nil)
        sqlite3_bind_text(stmt, 14, task.checksum?.value, -1, nil)
        
        // Dates
        let formatter = ISO8601DateFormatter()
        sqlite3_bind_text(stmt, 15, formatter.string(from: task.createdAt), -1, nil)
        
        if let startedAt = task.startedAt {
            sqlite3_bind_text(stmt, 16, formatter.string(from: startedAt), -1, nil)
        } else {
            sqlite3_bind_null(stmt, 16)
        }
        
        if let completedAt = task.completedAt {
            sqlite3_bind_text(stmt, 17, formatter.string(from: completedAt), -1, nil)
        } else {
            sqlite3_bind_null(stmt, 17)
        }
        
        sqlite3_bind_text(stmt, 18, metadataString, -1, nil)
        
        if sqlite3_step(stmt) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(db))
            print("Failed to save task: \(error)")
            return false
        } else {
            print("✅ Saved task: \(task.filename) (ID: \(task.id), Status: \(task.status.rawValue))")
            return true
        }
    }
    
    func loadTasks() async -> [DownloadTask] {
        // Check for corruption before load
        if isDatabaseCorrupted() {
            print("⚠️ Database corruption detected before load, recovering...")
            recoverDatabase()
        }
        
        guard db != nil else {
            print("❌ Database not available")
            return []
        }
        
        let query = """
            SELECT id, gid, url, filename, destination, size, completed_size, 
                   status, error_message, segments, speed_limit, category_id,
                   checksum_type, checksum_value, created_at, started_at, 
                   completed_at, metadata
            FROM downloads
            WHERE status != 'removed'
            ORDER BY created_at DESC
        """
        
        var tasks: [DownloadTask] = []
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let task = taskFromRow(stmt) {
                    tasks.append(task)
                    print("📖 Loaded task: \(task.filename) (ID: \(task.id), Status: \(task.status.rawValue))")
                }
            }
        } else {
            let error = String(cString: sqlite3_errmsg(db))
            print("Failed to load tasks: \(error)")
            
            if error.contains("malformed") || error.contains("corrupt") {
                recoverDatabase()
                // Retry load after recovery
                return await loadTasks()
            }
        }
        
        return tasks
    }
    
    func deleteTask(_ taskId: String) async {
        let query = "UPDATE downloads SET status = 'removed' WHERE id = ?"
        
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, taskId, -1, nil)
            
            if sqlite3_step(stmt) != SQLITE_DONE {
                print("Failed to delete task: \(String(cString: sqlite3_errmsg(db)))")
            }
        }
    }
    
    // MARK: - Category Operations
    
    func saveCategory(_ category: Category) async {
        let query = """
            INSERT OR REPLACE INTO categories 
            (id, name, destination, color, icon, naming_template, post_actions)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """
        
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(category.id))
            sqlite3_bind_text(stmt, 2, category.name, -1, nil)
            sqlite3_bind_text(stmt, 3, category.destination.path, -1, nil)
            sqlite3_bind_text(stmt, 4, category.color, -1, nil)
            sqlite3_bind_text(stmt, 5, category.icon, -1, nil)
            sqlite3_bind_text(stmt, 6, category.namingTemplate, -1, nil)
            
            if let postActionsData = try? JSONEncoder().encode(category.postActions),
               let postActionsString = String(data: postActionsData, encoding: .utf8) {
                sqlite3_bind_text(stmt, 7, postActionsString, -1, nil)
            } else {
                sqlite3_bind_text(stmt, 7, "[]", -1, nil)
            }
            
            if sqlite3_step(stmt) != SQLITE_DONE {
                print("Failed to save category: \(String(cString: sqlite3_errmsg(db)))")
            }
        }
    }
    
    func loadCategories() async -> [Category] {
        let query = "SELECT id, name, destination, color, icon FROM categories"
        
        var categories: [Category] = []
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let name = String(cString: sqlite3_column_text(stmt, 1))
                let destinationPath = String(cString: sqlite3_column_text(stmt, 2))
                let color = String(cString: sqlite3_column_text(stmt, 3))
                let icon = String(cString: sqlite3_column_text(stmt, 4))
                
                let destination = URL(fileURLWithPath: destinationPath)
                let category = Category(
                    id: id,
                    name: name,
                    destination: destination,
                    color: color,
                    icon: icon
                )
                categories.append(category)
            }
        }
        
        return categories
    }
    
    // MARK: - Security Bookmarks
    
    func saveSecurityBookmark(for url: URL) async {
        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            
            let query = """
                INSERT OR REPLACE INTO security_bookmarks (path, bookmark_data)
                VALUES (?, ?)
            """
            
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, url.path, -1, nil)
                _ = bookmarkData.withUnsafeBytes { bytes in
                    sqlite3_bind_blob(stmt, 2, bytes.baseAddress, Int32(bookmarkData.count), nil)
                }
                
                if sqlite3_step(stmt) != SQLITE_DONE {
                    print("Failed to save bookmark: \(String(cString: sqlite3_errmsg(db)))")
                }
            }
        } catch {
            print("Failed to create bookmark: \(error)")
        }
    }
    
    func loadSecurityBookmarks() async -> [URL] {
        let query = "SELECT path, bookmark_data FROM security_bookmarks"
        
        var urls: [URL] = []
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let blobPointer = sqlite3_column_blob(stmt, 1) {
                    let blobSize = sqlite3_column_bytes(stmt, 1)
                    let bookmarkData = Data(bytes: blobPointer, count: Int(blobSize))
                    
                    do {
                        var isStale = false
                        let url = try URL(
                            resolvingBookmarkData: bookmarkData,
                            options: .withSecurityScope,
                            relativeTo: nil,
                            bookmarkDataIsStale: &isStale
                        )
                        
                        if !isStale {
                            urls.append(url)
                        }
                    } catch {
                        print("Failed to resolve bookmark: \(error)")
                    }
                }
            }
        }
        
        return urls
    }
    
    // MARK: - Helpers
    
    private func taskFromRow(_ stmt: OpaquePointer?) -> DownloadTask? {
        guard let stmt = stmt else { return nil }
        
        let id = String(cString: sqlite3_column_text(stmt, 0))
        let gid = sqlite3_column_text(stmt, 1).flatMap { String(cString: $0) }
        let urlString = String(cString: sqlite3_column_text(stmt, 2))
        
        // Handle potentially NULL filename
        let filename: String
        if let filenamePtr = sqlite3_column_text(stmt, 3) {
            filename = String(cString: filenamePtr)
        } else {
            // Fallback to extracting from URL if filename is NULL
            if let url = URL(string: urlString) {
                filename = url.lastPathComponent.isEmpty ? "download" : url.lastPathComponent
            } else {
                filename = "download"
            }
            print("⚠️ Task \(id) had NULL filename, using: \(filename)")
        }
        
        let destinationPath = String(cString: sqlite3_column_text(stmt, 4))
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            return nil
        }
        
        // Handle destination path - it might be a file path, not a URL
        let destination = URL(fileURLWithPath: destinationPath)
        
        var task = DownloadTask(
            id: id,
            url: url,
            filename: filename,
            destination: destination,
            segments: Int(sqlite3_column_int(stmt, 9))
        )
        
        task.gid = gid
        task.size = sqlite3_column_type(stmt, 5) != SQLITE_NULL ? sqlite3_column_int64(stmt, 5) : nil
        task.completedSize = sqlite3_column_int64(stmt, 6)
        
        if let statusString = sqlite3_column_text(stmt, 7).flatMap({ String(cString: $0) }),
           let status = TaskStatus(rawValue: statusString) {
            task.status = status
        }
        
        task.errorMessage = sqlite3_column_text(stmt, 8).flatMap { String(cString: $0) }
        task.speedLimit = sqlite3_column_type(stmt, 10) != SQLITE_NULL ? Int(sqlite3_column_int(stmt, 10)) : nil
        
        // Parse dates
        let formatter = ISO8601DateFormatter()
        if let createdString = sqlite3_column_text(stmt, 14).flatMap({ String(cString: $0) }),
           let createdDate = formatter.date(from: createdString) {
            task.createdAt = createdDate
        }
        
        if let startedString = sqlite3_column_text(stmt, 15).flatMap({ String(cString: $0) }),
           let startedDate = formatter.date(from: startedString) {
            task.startedAt = startedDate
        }
        
        if let completedString = sqlite3_column_text(stmt, 16).flatMap({ String(cString: $0) }),
           let completedDate = formatter.date(from: completedString) {
            task.completedAt = completedDate
        }
        
        // Parse metadata
        if let metadataString = sqlite3_column_text(stmt, 17).flatMap({ String(cString: $0) }),
           let metadataData = metadataString.data(using: .utf8),
           let metadata = try? JSONDecoder().decode(TaskMetadata.self, from: metadataData) {
            task.metadata = metadata
        }
        
        return task
    }
    
    deinit {
        if db != nil {
            sqlite3_close_v2(db)
        }
    }
}