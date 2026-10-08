import Foundation

// Stable identifiers allow preferences to survive changes to displayed labels.
enum ShortcutConfiguration: String, CaseIterable {
    case controlOptionV
    case controlOptionH
    case off

    static let defaultsKey = "historyShortcut"

    static func restored(from identifier: String?) -> ShortcutConfiguration {
        identifier.flatMap(Self.init(rawValue:)) ?? .controlOptionV
    }

    var title: String {
        switch self {
        case .controlOptionV: return "Control–Option–V"
        case .controlOptionH: return "Control–Option–H"
        case .off: return "Off"
        }
    }
}
