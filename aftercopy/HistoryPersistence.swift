import Foundation

struct HistorySnapshot: Codable {
    let version: Int
    let items: [ClipboardItem]
}

struct LegacyHistorySnapshot: Codable {
    let version: Int
    let items: [String]
}

enum HistoryPersistenceError: Error {
    case preservedFileBlocksSave
}

final class HistoryPersistence {

    enum LoadResult: Equatable {
        case restored([ClipboardItem])
        case empty
        case unavailable
    }

    static let currentVersion = 2
    static let maxPersistedEntryCharacters = 64_000
    static let maxFileBytes = 16 * 1024 * 1024

    private struct VersionProbe: Codable {
        let version: Int?
    }

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

    static func isPersistable(_ item: ClipboardItem, maxTextCharacters: Int, maxPayloadBytes: Int) -> Bool {
        switch item.kind {
        case .text:
            return (item.text ?? "").count <= maxTextCharacters
        case .image, .richText, .html:
            return (item.data?.count ?? 0) <= maxPayloadBytes
        case .fileURLs:
            return !(item.urls ?? []).isEmpty
        }
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
        guard let probe = try? JSONDecoder().decode(VersionProbe.self, from: data) else {
            quarantineCurrentFile()
            return .unavailable
        }
        switch probe.version {
        case 1:
            guard let legacy = try? JSONDecoder().decode(LegacyHistorySnapshot.self, from: data) else {
                quarantineCurrentFile()
                return .unavailable
            }
            return .restored(legacy.items.map { ClipboardItem.text($0) })
        case Self.currentVersion:
            guard let snapshot = try? JSONDecoder().decode(HistorySnapshot.self, from: data) else {
                quarantineCurrentFile()
                return .unavailable
            }
            return .restored(snapshot.items)
        default:
            quarantineCurrentFile()
            return .unavailable
        }
    }

    func save(_ items: [ClipboardItem]) throws {
        if quarantineFailed, fileManager.fileExists(atPath: fileURL.path) {
            throw HistoryPersistenceError.preservedFileBlocksSave
        }
        let persistedItems = items.filter {
            Self.isPersistable($0, maxTextCharacters: Self.maxPersistedEntryCharacters,
                              maxPayloadBytes: ClipboardItem.maxPayloadBytes)
        }
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
