import Foundation
import GRDB

struct Session: Codable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var timestamp: Date
    var backend: String
    var durationMs: Int
    var latencyMs: Int
    var wordCount: Int
    var transcript: String
    var rating: String?

    static let databaseTableName = "sessions"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

@MainActor
final class SessionStore {
    static let shared = SessionStore()

    private var db: DatabaseQueue?

    private init() {
        do {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Murmur")
            try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
            let dbPath = support.appendingPathComponent("sessions.db").path
            db = try DatabaseQueue(path: dbPath)
            try setupSchema()
        } catch {
            print("SessionStore init error: \(error)")
        }
    }

    private func setupSchema() throws {
        try db?.write { db in
            try db.create(table: "sessions", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("timestamp", .datetime).notNull()
                t.column("backend", .text).notNull()
                t.column("durationMs", .integer).notNull()
                t.column("latencyMs", .integer).notNull()
                t.column("wordCount", .integer).notNull()
                t.column("transcript", .text).notNull()
                t.column("rating", .text)
            }
        }
    }

    func save(_ session: inout Session) throws {
        try db?.write { db in
            try session.save(db)
        }
    }

    func updateRating(id: Int64, rating: String) throws {
        try db?.write { db in
            try db.execute(sql: "UPDATE sessions SET rating = ? WHERE id = ?", arguments: [rating, id])
        }
    }

    func fetchAll() throws -> [Session] {
        try db?.read { db in
            try Session.order(Column("timestamp").desc).fetchAll(db)
        } ?? []
    }

    func fetchRecent(limit: Int = 5) throws -> [Session] {
        try db?.read { db in
            try Session.order(Column("timestamp").desc).limit(limit).fetchAll(db)
        } ?? []
    }

    struct BackendStats {
        var backend: String
        var totalSessions: Int
        var ratedSessions: Int
        var goodCount: Int
        var okCount: Int
        var badCount: Int
        var avgLatencyMs: Double
        var avgWordCount: Double

        var avgRatingScore: Double {
            guard ratedSessions > 0 else { return 0 }
            return Double(goodCount * 3 + okCount * 2 + badCount * 1) / Double(ratedSessions)
        }
    }

    func fetchStats() throws -> [BackendStats] {
        try db?.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT backend,
                       COUNT(*) as total,
                       COUNT(rating) as rated,
                       SUM(CASE WHEN rating = 'good' THEN 1 ELSE 0 END) as good,
                       SUM(CASE WHEN rating = 'ok' THEN 1 ELSE 0 END) as ok,
                       SUM(CASE WHEN rating = 'bad' THEN 1 ELSE 0 END) as bad,
                       AVG(latencyMs) as avgLatency,
                       AVG(wordCount) as avgWords
                FROM sessions
                GROUP BY backend
                """)

            return rows.map { row in
                BackendStats(
                    backend: row["backend"],
                    totalSessions: row["total"],
                    ratedSessions: row["rated"],
                    goodCount: row["good"],
                    okCount: row["ok"],
                    badCount: row["bad"],
                    avgLatencyMs: row["avgLatency"],
                    avgWordCount: row["avgWords"]
                )
            }
        } ?? []
    }

    func totalRatedSessions() throws -> Int {
        try db?.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sessions WHERE rating IS NOT NULL") ?? 0
        } ?? 0
    }

    func exportCSV() throws -> String {
        let sessions = try fetchAll()
        var csv = "id,timestamp,backend,duration_ms,latency_ms,word_count,transcript,rating\n"
        let fmt = ISO8601DateFormatter()
        for s in sessions {
            let transcript = s.transcript.replacingOccurrences(of: "\"", with: "\"\"")
            csv += "\(s.id ?? 0),\(fmt.string(from: s.timestamp)),\(s.backend),\(s.durationMs),\(s.latencyMs),\(s.wordCount),\"\(transcript)\",\(s.rating ?? "")\n"
        }
        return csv
    }
}
