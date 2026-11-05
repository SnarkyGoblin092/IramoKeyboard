import Foundation
import SQLite3

/// A helper for managing the SQLite connection and providing common query results.
class SQLiteHelper {
    static let shared = SQLiteHelper()
    private var db: OpaquePointer?

    init() {
        // This will be initialized per language, so we need a way to handle multiple connections if needed,
        // but for simplicity, we'll assume one connection at a time or use a cache.
    }

    func openDatabase(at url: URL) -> OpaquePointer? {
        if sqlite3_open(url.path, &db) != SQLITE_OK {
            return nil
        }
        return db
    }

    func closeDatabase() {
        sqlite3_close(db)
        db = nil
    }
}
