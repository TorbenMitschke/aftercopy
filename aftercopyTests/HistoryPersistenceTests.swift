import XCTest
@testable import aftercopy

final class HistoryPersistenceTests: XCTestCase {

    private var directory: URL!
    private var fileURL: URL!
    private var persistence: HistoryPersistence!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("aftercopy-tests-\(UUID().uuidString)", isDirectory: true)
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("history.json")
        persistence = HistoryPersistence(fileURL: fileURL)
    }

    override func tearDown() {
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
        try? FileManager.default.removeItem(at: directory)
        directory = nil
        fileURL = nil
        persistence = nil
        super.tearDown()
    }

    func test_load_missingFile_returnsEmpty() {
        XCTAssertEqual(persistence.load(), .empty)
    }

    func test_saveThenLoad_roundTripsItemsInOrder() throws {
        try persistence.save([.text("first"), .text("second"), .text("third")])
        XCTAssertEqual(persistence.load(), .restored([.text("first"), .text("second"), .text("third")]))
    }

    func test_saveThenLoad_roundTripsRichItem() throws {
        let image = ClipboardItem(kind: .image, text: nil, data: Data([9, 8, 7]), dataType: "public.png", urls: nil)
        let files = ClipboardItem(kind: .fileURLs, text: nil, data: nil, dataType: nil,
                                  urls: ["file:///Users/x/a.txt"])
        try persistence.save([image, files])
        XCTAssertEqual(persistence.load(), .restored([image, files]))
    }

    func test_load_version1File_migratesToTextItems() throws {
        let legacy = LegacyHistorySnapshot(version: 1, items: ["first", "second"])
        try JSONEncoder().encode(legacy).write(to: fileURL)
        XCTAssertEqual(persistence.load(), .restored([.text("first"), .text("second")]))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func test_save_emptyList_loadsAsRestoredEmpty() throws {
        try persistence.save([])
        XCTAssertEqual(persistence.load(), .restored([]))
    }

    func test_load_corruptJSON_returnsUnavailableAndPreservesFile() throws {
        try "not json".write(to: fileURL, atomically: false, encoding: .utf8)
        XCTAssertEqual(persistence.load(), .unavailable)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        let preserved = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertEqual(preserved.count, 1)
        XCTAssertTrue(preserved.first?.hasPrefix("history.json.corrupt-") ?? false)
    }

    func test_load_unsupportedVersion_returnsUnavailableAndPreservesFile() throws {
        let snapshot = LegacyHistorySnapshot(version: 999, items: ["entry"])
        try JSONEncoder().encode(snapshot).write(to: fileURL)
        XCTAssertEqual(persistence.load(), .unavailable)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        let preserved = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertEqual(preserved.count, 1)
        XCTAssertTrue(preserved.first?.hasPrefix("history.json.corrupt-") ?? false)
    }

    func test_load_oversizedFile_returnsUnavailableAndPreservesFile() throws {
        let oversized = Data(repeating: 0, count: HistoryPersistence.maxFileBytes + 1)
        try oversized.write(to: fileURL)
        XCTAssertEqual(persistence.load(), .unavailable)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        let preserved = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertEqual(preserved.count, 1)
        XCTAssertTrue(preserved.first?.hasPrefix("history.json.corrupt-") ?? false)
    }

    func test_save_excludesOversizedTextEntries() throws {
        let oversized = String(repeating: "a", count: HistoryPersistence.maxPersistedEntryCharacters + 1)
        try persistence.save([.text("small entry"), .text(oversized)])
        XCTAssertEqual(persistence.load(), .restored([.text("small entry")]))
    }

    func test_save_excludesOversizedPayloads() throws {
        let oversized = Data(repeating: 0, count: ClipboardItem.maxPayloadBytes + 1)
        let item = ClipboardItem(kind: .image, text: nil, data: oversized, dataType: "public.png", urls: nil)
        try persistence.save([.text("small entry"), item])
        XCTAssertEqual(persistence.load(), .restored([.text("small entry")]))
    }

    func test_isPersistable_textRespectsCharacterCap() {
        let small = ClipboardItem.text(String(repeating: "a", count: 100))
        let large = ClipboardItem.text(String(repeating: "a", count: 64_001))
        XCTAssertTrue(HistoryPersistence.isPersistable(small, maxTextCharacters: 64_000, maxPayloadBytes: 100))
        XCTAssertFalse(HistoryPersistence.isPersistable(large, maxTextCharacters: 64_000, maxPayloadBytes: 100))
    }

    func test_isPersistable_fileURLsRequireAtLeastOneURL() {
        let withURL = ClipboardItem.make(kind: .fileURLs, urls: ["file:///a"])
        let without = ClipboardItem.make(kind: .fileURLs, urls: [])
        XCTAssertTrue(HistoryPersistence.isPersistable(withURL!, maxTextCharacters: 64_000, maxPayloadBytes: 100))
        XCTAssertFalse(HistoryPersistence.isPersistable(without!, maxTextCharacters: 64_000, maxPayloadBytes: 100))
    }

    func test_save_writeFailure_throws() throws {
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: directory.path)
        XCTAssertThrowsError(try persistence.save([.text("entry")]))
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
    }

    func test_clear_removesFile() throws {
        try persistence.save([.text("entry")])
        try persistence.clear()
        XCTAssertEqual(persistence.load(), .empty)
    }

    func test_clear_missingFile_doesNotThrow() {
        XCTAssertNoThrow(try persistence.clear())
    }

    func test_save_afterUnavailableLoad_writesFreshFile() throws {
        try "not json".write(to: fileURL, atomically: false, encoding: .utf8)
        XCTAssertEqual(persistence.load(), .unavailable)
        try persistence.save([.text("recovered")])
        XCTAssertEqual(persistence.load(), .restored([.text("recovered")]))
    }
}
