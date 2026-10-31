import ServiceManagement

final class LoginItemManager {
    private var failureMessage: String?
    private var failedStatus: SMAppService.Status?

    var isRegistered: Bool { LoginItemState(status: SMAppService.mainApp.status).isRegistered }

    var statusMessage: String? {
        let status = SMAppService.mainApp.status
        if status != failedStatus {
            failureMessage = nil
            failedStatus = nil
        }
        return failureMessage ?? LoginItemState(status: status).message
    }

    func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        failureMessage = nil
        failedStatus = nil
        do {
            if enabled {
                if service.status == .requiresApproval {
                    // Already registered; the user must approve it in System Settings.
                    SMAppService.openSystemSettingsLoginItems()
                } else if service.status != .enabled {
                    try service.register()
                }
            } else if service.status != .notRegistered {
                try service.unregister()
            }
        } catch {
            failedStatus = service.status
            failureMessage = LoginItemState.failureMessage(enabling: enabled)
            throw error
        }
    }
}
