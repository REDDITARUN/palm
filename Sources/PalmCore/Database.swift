import Foundation
import GRDB
import Security

public final class LocalDatabase {
    private let queue: DatabaseQueue
    private var indexedNotes: [StudyNote]?
    public let directory: URL
    public init(directory: URL? = nil, appVersion: String? = nil) throws {
        self.directory = directory ?? Self.defaultDirectory()
        try FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
        queue = try DatabaseQueue(path: self.directory.appendingPathComponent("plam.sqlite").path)
        // Take a SQLite-consistent safety copy before any future schema migration.
        // This stamp belongs to the library, so replacing the app never resets it.
        let stamp = self.directory.appendingPathComponent("app-version.txt")
        let previous = try? String(contentsOf: stamp, encoding: .utf8)
        if let appVersion, previous != appVersion, try queue.read({ try $0.tableExists("state") }) {
            let backups = self.directory.appendingPathComponent("UpgradeBackups", isDirectory: true)
            try FileManager.default.createDirectory(at: backups, withIntermediateDirectories: true)
            let target = try DatabaseQueue(path: backups.appendingPathComponent(UUID().uuidString + ".sqlite").path)
            try queue.backup(to: target)
        }
        var migrator = DatabaseMigrator()
        migrator.registerMigration("initial") { db in
            try db.execute(sql: "CREATE TABLE state (id INTEGER PRIMARY KEY, json BLOB NOT NULL)")
            try db.execute(sql: "CREATE TABLE note_revisions (id TEXT PRIMARY KEY, noteID TEXT NOT NULL, created REAL NOT NULL, json BLOB NOT NULL)")
            try db.execute(sql: "CREATE VIRTUAL TABLE note_search USING fts5(id UNINDEXED, title, body)")
        }
        migrator.registerMigration("workspace-documents") { db in
            try db.execute(sql: "CREATE TABLE documents (id TEXT PRIMARY KEY, json BLOB NOT NULL)")
            try db.execute(sql: "CREATE TABLE conversations (id TEXT PRIMARY KEY, json BLOB NOT NULL)")
        }
        try migrator.migrate(queue)
        if let appVersion { try appVersion.write(to: stamp, atomically: true, encoding: .utf8) }
    }
    /// Keep existing snapshots and runtime paths valid; fresh installs use the corrected name.
    public static func defaultDirectory(applicationSupport: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]) -> URL {
        let legacy = applicationSupport.appendingPathComponent("Plam", isDirectory: true)
        if FileManager.default.fileExists(atPath: legacy.appendingPathComponent("plam.sqlite").path) { return legacy }
        return applicationSupport.appendingPathComponent("Palm", isDirectory: true)
    }
    public func load() throws -> AppData {
        try queue.read { db in
            guard let blob = try Data.fetchOne(db, sql: "SELECT json FROM state WHERE id = 1") else { return AppData() }
            var data = try JSONDecoder().decode(AppData.self, from: blob)
            let notes = try Data.fetchAll(db, sql: "SELECT json FROM documents").map { try JSONDecoder().decode(StudyNote.self, from: $0) }
            let conversations = try Data.fetchAll(db, sql: "SELECT json FROM conversations").map { try JSONDecoder().decode(TutorConversation.self, from: $0) }
            if !notes.isEmpty { data.notes = notes }
            if !conversations.isEmpty { data.conversations = conversations }
            guard data.schemaVersion == 1 else { throw PalmError.message("This library was created by a newer Palm version. Your data has not been changed.") }
            return data
        }
    }
    public func save(_ data: AppData, revision: NoteRevision? = nil) throws {
        try write(data, revisions: revision.map { [$0] } ?? [], replaceRevisions: false)
    }
    private func write(_ data: AppData, revisions: [NoteRevision], replaceRevisions: Bool) throws {
        var state = data
        state.notes = []; state.conversations = nil
        let blob = try JSONEncoder().encode(state)
        let notesChanged = indexedNotes != data.notes
        try queue.write { db in
            try db.execute(sql: "INSERT INTO state(id,json) VALUES (1,?) ON CONFLICT(id) DO UPDATE SET json=excluded.json", arguments: [blob])
            if replaceRevisions { try db.execute(sql: "DELETE FROM note_revisions") }
            for revision in revisions {
                try db.execute(sql: "INSERT INTO note_revisions VALUES (?,?,?,?)", arguments: [revision.id.uuidString, revision.noteID.uuidString, revision.createdAt.timeIntervalSince1970, try JSONEncoder().encode(revision)])
            }
            let ids = Set(data.notes.map { $0.id.uuidString })
            for id in try String.fetchAll(db, sql: "SELECT id FROM documents") where !ids.contains(id) {
                try db.execute(sql: "DELETE FROM documents WHERE id=?", arguments: [id])
                try db.execute(sql: "DELETE FROM note_search WHERE id=?", arguments: [id])
            }
            if notesChanged {
                for note in data.notes where indexedNotes?.first(where: { $0.id == note.id }) != note {
                    try Self.writeNote(note, in: db)
                }
            }
            let chatIDs = Set((data.conversations ?? []).map(\.id))
            for id in try String.fetchAll(db, sql: "SELECT id FROM conversations") where !chatIDs.contains(id) { try db.execute(sql: "DELETE FROM conversations WHERE id=?", arguments: [id]) }
            for conversation in data.conversations ?? [] { try Self.writeConversation(conversation, in: db) }

        }
        indexedNotes = data.notes
    }
    private static func writeNote(_ note: StudyNote, in db: Database) throws {
        try db.execute(sql: "INSERT INTO documents(id,json) VALUES (?,?) ON CONFLICT(id) DO UPDATE SET json=excluded.json", arguments: [note.id.uuidString, try JSONEncoder().encode(note)])
        try db.execute(sql: "DELETE FROM note_search WHERE id=?", arguments: [note.id.uuidString])
        try db.execute(sql: "INSERT INTO note_search(id,title,body) VALUES (?,?,?)", arguments: [note.id.uuidString, note.title, note.body])
    }
    private static func writeConversation(_ conversation: TutorConversation, in db: Database) throws {
        try db.execute(sql: "INSERT INTO conversations(id,json) VALUES (?,?) ON CONFLICT(id) DO UPDATE SET json=excluded.json", arguments: [conversation.id, try JSONEncoder().encode(conversation)])
    }
    public func saveNote(_ note: StudyNote, revision: NoteRevision? = nil) throws {
        try queue.write { db in
            try Self.writeNote(note, in: db)
            if let revision { try db.execute(sql: "INSERT INTO note_revisions VALUES (?,?,?,?)", arguments: [revision.id.uuidString, revision.noteID.uuidString, revision.createdAt.timeIntervalSince1970, try JSONEncoder().encode(revision)]) }
        }
        if let index = indexedNotes?.firstIndex(where: { $0.id == note.id }) { indexedNotes?[index] = note }
    }
    public func saveConversation(_ conversation: TutorConversation) throws { try queue.write { try Self.writeConversation(conversation, in: $0) } }
    public func revisions(for id: UUID) throws -> [NoteRevision] {
        try queue.read { db in
            try Data.fetchAll(db, sql: "SELECT json FROM note_revisions WHERE noteID=? ORDER BY created DESC LIMIT 100", arguments: [id.uuidString]).map { try JSONDecoder().decode(NoteRevision.self, from: $0) }
        }
    }
    public func searchNotes(_ query: String) throws -> Set<UUID> {
        let tokens = query.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map { "\"\($0)\"*" }
        guard !tokens.isEmpty else { return [] }
        return try queue.read { db in
            Set(try String.fetchAll(db, sql: "SELECT id FROM note_search WHERE note_search MATCH ? ORDER BY rank", arguments: [tokens.joined(separator: " AND ")]).compactMap(UUID.init(uuidString:)))
        }
    }
    public func backup(to url: URL) throws {
        let destination = try DatabaseQueue(path: url.path)
        try queue.backup(to: destination)
    }
    public func export(_ data: AppData, to url: URL) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(data).write(to: url, options: .atomic)
    }
    public func importData(from url: URL) throws -> AppData {
        let imported = try JSONDecoder().decode(AppData.self, from: Data(contentsOf: url))
        guard imported.schemaVersion == 1 else { throw PalmError.message("Unsupported backup version.") }
        try LearningEngine.validateLibrary(imported)
        return imported
    }
    /// A portable folder contains canonical records, revisions, and every referenced code snapshot.
    /// Derived indexes and credentials are deliberately rebuilt or read from Keychain after restore.
    public func exportBackup(_ data: AppData, to destination: URL) throws {
        try LearningEngine.validateLibrary(data)
        let fm = FileManager.default
        guard !fm.fileExists(atPath: destination.path) else { throw PalmError.message("Choose a new backup name; an existing backup will not be overwritten.") }
        let staging = destination.deletingLastPathComponent().appendingPathComponent(".palm-backup-" + UUID().uuidString)
        try fm.createDirectory(at: staging.appendingPathComponent("Snapshots"), withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: staging) }
        var paths = Set(data.repositories.map(\.snapshotPath))
        paths.formUnion(data.sessions.compactMap(\.snapshotPath))
        var snapshots: [String: String] = [:]
        for path in paths {
            let name = UUID().uuidString
            let source = URL(fileURLWithPath: path)
            try Self.validateSnapshotTree(source)
            try fm.copyItem(at: source, to: staging.appendingPathComponent("Snapshots").appendingPathComponent(name))
            snapshots[path] = name
        }
        let revisions = try queue.read { db in
            try Data.fetchAll(db, sql: "SELECT json FROM note_revisions ORDER BY created").map { try JSONDecoder().decode(NoteRevision.self, from: $0) }
        }
        var clean = data; clean.preferences.context7Key = ""
        for i in clean.memories.indices { clean.memories[i].vectorID = nil }
        let archive = LibraryBackup(data: clean, revisions: revisions.filter { r in clean.notes.contains { $0.id == r.noteID } }, snapshots: snapshots)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(archive).write(to: staging.appendingPathComponent("library.json"), options: .atomic)
        try fm.moveItem(at: staging, to: destination)
    }

    public func restoreBackup(from source: URL) throws -> AppData {
        let fm = FileManager.default
        let archive = try JSONDecoder().decode(LibraryBackup.self, from: Data(contentsOf: source.appendingPathComponent("library.json")))
        guard archive.version == 1 else { throw PalmError.message("Unsupported backup version.") }
        try LearningEngine.validateLibrary(archive.data)
        guard Set(archive.revisions.map(\.id)).count == archive.revisions.count,
              archive.revisions.allSatisfy({ r in archive.data.notes.contains { $0.id == r.noteID } }) else { throw PalmError.message("This backup contains invalid note revisions.") }
        var paths = Set(archive.data.repositories.map(\.snapshotPath))
        paths.formUnion(archive.data.sessions.compactMap(\.snapshotPath))
        guard paths == Set(archive.snapshots.keys), Set(archive.snapshots.values).count == paths.count else { throw PalmError.message("This backup is missing a code snapshot.") }
        for name in archive.snapshots.values {
            guard UUID(uuidString: name) != nil else { throw PalmError.message("Invalid snapshot path in backup.") }
            let packaged = source.appendingPathComponent("Snapshots").appendingPathComponent(name)
            let root = source.resolvingSymlinksInPath().standardizedFileURL.path
            guard packaged.resolvingSymlinksInPath().standardizedFileURL.path.hasPrefix(root + "/") else { throw PalmError.message("A snapshot points outside this backup.") }
            try Self.validateSnapshotTree(packaged)
        }
        let restored = directory.appendingPathComponent("Snapshots/Restored-" + UUID().uuidString)
        try fm.createDirectory(at: restored, withIntermediateDirectories: true)
        var committed = false
        defer { if !committed { try? fm.removeItem(at: restored) } }
        for name in archive.snapshots.values {
            try fm.copyItem(at: source.appendingPathComponent("Snapshots").appendingPathComponent(name), to: restored.appendingPathComponent(name))
        }
        var next = archive.data
        func relocated(_ path: String) -> String { restored.appendingPathComponent(archive.snapshots[path]!).path }
        for i in next.repositories.indices { next.repositories[i].snapshotPath = relocated(next.repositories[i].snapshotPath) }
        for i in next.sessions.indices { if let path = next.sessions[i].snapshotPath { next.sessions[i].snapshotPath = relocated(path) } }
        Self.prepareRestoredData(&next)
        try backup(to: directory.appendingPathComponent("before-restore-" + UUID().uuidString + ".sqlite"))
        try write(next, revisions: archive.revisions, replaceRevisions: true)
        committed = true
        return next
    }

    public func restoreJSON(from source: URL) throws -> AppData {
        var next = try importData(from: source)
        Self.prepareRestoredData(&next)
        try backup(to: directory.appendingPathComponent("before-restore-" + UUID().uuidString + ".sqlite"))
        try write(next, revisions: [], replaceRevisions: true)
        return next
    }

    private static func prepareRestoredData(_ data: inout AppData) {
        data.preferences.context7Key = ""
        for i in data.memories.indices { data.memories[i].vectorID = nil }
        for i in data.jobs.indices where data.jobs[i].status == "running" {
            data.jobs[i].status = "interrupted"; data.jobs[i].error = "Restored from backup. Retry this activity to continue."
        }
    }

    private static func validateSnapshotTree(_ url: URL) throws {
        let fm = FileManager.default
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true else { throw PalmError.message("A code snapshot is missing or contains a symbolic link.") }
        var traversalError: Error?
        guard let files = fm.enumerator(at: url, includingPropertiesForKeys: [.isSymbolicLinkKey, .isRegularFileKey, .isDirectoryKey], errorHandler: { _, error in traversalError = error; return false }) else { throw PalmError.message("A code snapshot could not be read.") }
        for case let file as URL in files {
            let flags = try file.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey, .isDirectoryKey])
            guard flags.isSymbolicLink != true, flags.isRegularFile == true || flags.isDirectory == true else { throw PalmError.message("A snapshot contains an unsupported file or symbolic link.") }
        }
        if let traversalError { throw traversalError }
    }

}

private struct LibraryBackup: Codable {
    var version = 1
    var data: AppData
    var revisions: [NoteRevision]
    var snapshots: [String: String]
}

public enum Keychain {
    private static let service = "app.plam.learning"
    public static func read(_ account: String) -> String? {
        var result: CFTypeRef?
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    public static func save(_ value: String, account: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        if value.isEmpty {
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw PalmError.message("Keychain could not remove the credential (\(status)).") }
            return
        }
        let attributes: [String: Any] = [kSecValueData as String: Data(value.utf8)]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = query; item.merge(attributes) { _, new in new }; item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw PalmError.message("Keychain could not save the credential (\(status)).") }
    }
}
