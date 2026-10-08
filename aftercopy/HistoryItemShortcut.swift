import Foundation

enum HistoryItemShortcut {
    static func keyEquivalent(for index: Int) -> String? {
        guard (0..<10).contains(index) else { return nil }
        return index == 9 ? "0" : String(index + 1)
    }
}
