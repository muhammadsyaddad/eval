import Foundation
import GRDB

// MARK: - Database Manager

/// Manages the SQLite database lifecycle: creation, migrations, and access.
/// Uses GRDB's DatabasePool for concurrent reads and serialized writes.
final class DatabaseManager {

    /// The shared database pool for the app.
    let dbPool: DatabasePool

    /// Path to the database file.
    let databaseURL: URL

    /// Creates a DatabaseManager backed by a file at the given URL.
    /// If no URL is provided, defaults to ~/Library/Application Support/MacPulse/macpulse.db
    init(databaseURL: URL? = nil) throws {
        let url = databaseURL ?? Self.defaultDatabaseURL()
        self.databaseURL = url

        // Ensure parent directory exists
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var config = Configuration()
        config.prepareDatabase { db in
            // Enable WAL mode for better concurrency
            try db.execute(sql: "PRAGMA journal_mode=WAL")
        }

        self.dbPool = try DatabasePool(path: url.path, configuration: config)
        try runMigrations()
    }

    /// Creates an in-memory DatabaseManager for testing.
    static func inMemory() throws -> DatabaseManager {
        try DatabaseManager(databaseURL: URL(fileURLWithPath: ":memory:"))
    }

    /// Default database path: ~/Library/Application Support/MacPulse/macpulse.db
    static func defaultDatabaseURL() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport
            .appendingPathComponent("MacPulse", isDirectory: true)
            .appendingPathComponent("macpulse.db")
    }

    /// Total size of the database file on disk (bytes).
    func databaseSizeBytes() -> UInt64 {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: databaseURL.path),
              let size = attrs[.size] as? UInt64
        else { return 0 }
        return size
    }

    /// Run VACUUM to reclaim disk space after large deletes.
    /// Note: VACUUM rebuilds the entire database file, so it temporarily doubles disk usage.
    /// Should be called after bulk data deletion (e.g., clearAllData).
    func vacuumDatabase() throws {
        try dbPool.barrierWriteWithoutTransaction { db in
            try db.execute(sql: "VACUUM")
        }
    }

    // MARK: - Migrations

    private func runMigrations() throws {
        var migrator = DatabaseMigrator()

        // M3 v1: Initial schema
        migrator.registerMigration("v1_initial") { db in
            // ── captures table ──
            // PRIVACY: This table contains the most sensitive data in the app.
            // Each row represents a single screen capture with full metadata.
            try db.create(table: "captures") { t in
                t.primaryKey("id", .text).notNull()          // UUID string
                t.column("timestamp", .datetime).notNull()
                    .indexed()
                t.column("appName", .text).notNull()          // PRIVACY: Low sensitivity — app name
                t.column("bundleIdentifier", .text).notNull() // PRIVACY: Low sensitivity — bundle ID
                t.column("windowTitle", .text).notNull()      // PRIVACY: Medium — may contain document names, email subjects, URLs
                t.column("browserURL", .text)                 // PRIVACY: High — reveals browsing history
                t.column("imagePath", .text).notNull()        // PRIVACY: High — path to screenshot PNG on disk
                t.column("ocrText", .text)                    // PRIVACY: High — contains whatever text was on screen
                t.column("ocrConfidence", .double)
            }

            // ── activity_entries table ──
            // PRIVACY: Contains AI-generated summaries of user activity.
            // Summary text may describe what the user was doing in natural language.
            try db.create(table: "activity_entries") { t in
                t.primaryKey("id", .text).notNull()          // UUID string
                t.column("timestamp", .datetime).notNull()
                    .indexed()
                t.column("appName", .text).notNull()
                t.column("appIcon", .text).notNull()
                t.column("title", .text).notNull()            // PRIVACY: Medium — activity title derived from window
                t.column("summary", .text).notNull()          // PRIVACY: Medium — AI-generated description of user activity
                t.column("category", .text).notNull()
                t.column("duration", .double).notNull()
            }

            // ── daily_summaries table ──
            // PRIVACY: Aggregated daily summaries. Lower sensitivity than raw captures
            // but aiSummary may reference specific activities.
            try db.create(table: "daily_summaries") { t in
                t.primaryKey("id", .text).notNull()          // UUID string
                t.column("date", .date).notNull()
                    .unique()                                 // one summary per day
                    .indexed()
                t.column("totalScreenTime", .double).notNull()
                t.column("aiSummary", .text).notNull()        // PRIVACY: Medium — natural language day summary
                t.column("activityCount", .integer).notNull()
                t.column("productivityScore", .double).notNull()
            }

            // ── app_usage table ──
            // PRIVACY: Low sensitivity — only app names and durations per day.
            try db.create(table: "app_usage") { t in
                t.primaryKey("id", .text).notNull()          // UUID string
                t.column("date", .date).notNull()
                    .indexed()
                t.column("appName", .text).notNull()
                t.column("appIcon", .text).notNull()
                t.column("duration", .double).notNull()
                t.column("category", .text).notNull()
                // Composite unique: one entry per app per day
                t.uniqueKey(["date", "appName"])
            }

            // ── FTS5 virtual table for full-text search on captures ──
            try db.create(virtualTable: "captures_fts", using: FTS5()) { t in
                t.synchronize(withTable: "captures")
                t.tokenizer = .porter(wrapping: .unicode61())
                t.column("ocrText")
                t.column("appName")
                t.column("windowTitle")
            }

            // ── FTS5 virtual table for full-text search on activity entries ──
            try db.create(virtualTable: "activity_entries_fts", using: FTS5()) { t in
                t.synchronize(withTable: "activity_entries")
                t.tokenizer = .porter(wrapping: .unicode61())
                t.column("title")
                t.column("summary")
            }

            // ── FTS5 virtual table for full-text search on daily summaries ──
            try db.create(virtualTable: "daily_summaries_fts", using: FTS5()) { t in
                t.synchronize(withTable: "daily_summaries")
                t.tokenizer = .porter(wrapping: .unicode61())
                t.column("aiSummary")
            }
        }

        try migrator.migrate(dbPool)
    }
}
