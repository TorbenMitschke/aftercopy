import ServiceManagement

nonisolated struct LoginItemState {
    let isRegistered: Bool
    let message: String?

    init(status: SMAppService.Status) {
        isRegistered = status == .enabled
        switch status {
        case .enabled, .notRegistered:
            message = nil
        case .requiresApproval:
            message = "Launch at Login: allow aftercopy in System Settings → General → Login Items"
        case .notFound:
            message = "Launch at Login: app service not found; reinstall the app"
        @unknown default:
            message = "Launch at Login: status unavailable"
        }
    }

    static func failureMessage(enabling: Bool) -> String {
        enabling ? "Launch at Login: could not enable; check installation and Login Items in System Settings"
            : "Launch at Login: could not disable; check Login Items in System Settings"
    }
}
