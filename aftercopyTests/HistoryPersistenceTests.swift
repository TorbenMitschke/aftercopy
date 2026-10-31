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
        try persistence.save(["first", "second", "third"])
        XCTAssertEqual(persistence.load(), .restored(["first", "second", "third"]))
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
        let snapshot = HistorySnapshot(version: 999, items: ["entry"])
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

    func test_save_excludesOversizedEntries() throws {
        let oversized = String(repeating: "a", count: HistoryPersistence.maxPersistedEntryCharacters + 1)
        try persistence.save(["small entry", oversized])
        XCTAssertEqual(persistence.load(), .restored(["small entry"]))
    }

    func test_save_writeFailure_throws() throws {
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: directory.path)
        XCTAssertThrowsError(try persistence.save(["entry"]))
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
    }

    func test_clear_removesFile() throws {
        try persistence.save(["entry"])
        try persistence.clear()
        XCTAssertEqual(persistence.load(), .empty)
    }

    func test_clear_missingFile_doesNotThrow() {
        XCTAssertNoThrow(try persistence.clear())
    }

    func test_save_afterUnavailableLoad_writesFreshFile() throws {
        try "not json".write(to: fileURL, atomically: false, encoding: .utf8)
        XCTAssertEqual(persistence.load(), .unavailable)
        try persistence.save(["recovered"])
        XCTAssertEqual(persistence.load(), .restored(["recovered"]))
    }
}
