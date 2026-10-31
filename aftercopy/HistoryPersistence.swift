import Foundation

struct HistorySnapshot: Codable {
    let version: Int
    let items: [String]
}

enum HistoryPersistenceError: Error {
    case preservedFileBlocksSave
}

final class HistoryPersistence {

    enum LoadResult: Equatable {
        case restored([String])
        case empty
        case unavailable
    }

    static let currentVersion = 1
    static let maxPersistedEntryCharacters = 64_000
    static let maxFileBytes = 16 * 1024 * 1024

    private let fileURL: URL
    private let fileManager: FileManager
    private var quarantineFailed = false

    nonisolated deinit {}

    init(fileURL: URL = HistoryPersistence.defaultFileURL(), fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    static func defaultFileURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return appSupport.appendingPathComponent("aftercopy/history.json")
    }

    func load() -> LoadResult {
        quarantineFailed = false
        guard fileManager.fileExists(atPath: fileURL.path) else { return .empty }
        guard let data = fileManager.contents(atPath: fileURL.path) else {
            quarantineCurrentFile()
            return .unavailable
        }
        if data.count > Self.maxFileBytes {
            quarantineCurrentFile()
            return .unavailable
        }
        guard let snapshot = try? JSONDecoder().decode(HistorySnapshot.self, from: data),
              snapshot.version == Self.currentVersion else {
            quarantineCurrentFile()
            return .unavailable
        }
        return .restored(snapshot.items)
    }

    func save(_ items: [String]) throws {
        if quarantineFailed, fileManager.fileExists(atPath: fileURL.path) {
            throw HistoryPersistenceError.preservedFileBlocksSave
        }
        let persistedItems = items.filter { $0.count <= Self.maxPersistedEntryCharacters }
        let snapshot = HistorySnapshot(version: Self.currentVersion, items: persistedItems)
        let data = try JSONEncoder().encode(snapshot)
        let directory = fileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        try data.write(to: fileURL, options: .atomic)
    }

    func clear() throws {
        quarantineFailed = false
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }

    private func quarantineCurrentFile() {
        let quarantineURL = fileURL.deletingLastPathComponent()
            .appendingPathComponent("\(fileURL.lastPathComponent).corrupt-\(Int(Date().timeIntervalSince1970))")
        do {
            try fileManager.moveItem(at: fileURL, to: quarantineURL)
        } catch {
            quarantineFailed = true
        }
    }
}
