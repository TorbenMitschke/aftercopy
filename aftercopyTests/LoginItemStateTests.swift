import XCTest
import ServiceManagement
@testable import aftercopy

final class LoginItemStateTests: XCTestCase {
    func test_enabledIsCheckedWithoutWarning() {
        let state = LoginItemState(status: .enabled)
        XCTAssertTrue(state.isRegistered)
        XCTAssertNil(state.message)
    }
    func test_unregisteredIsUncheckedWithoutWarning() {
        let state = LoginItemState(status: .notRegistered)
        XCTAssertFalse(state.isRegistered)
        XCTAssertNil(state.message)
    }
    func test_approvalRequiredIsUncheckedWithGuidance() {
        let state = LoginItemState(status: .requiresApproval)
        XCTAssertFalse(state.isRegistered)
        XCTAssertEqual(state.message, "Launch at Login: allow aftercopy in System Settings → General → Login Items")
    }
    func test_missingServiceSuggestsReinstallation() {
        let state = LoginItemState(status: .notFound)
        XCTAssertFalse(state.isRegistered)
        XCTAssertEqual(state.message, "Launch at Login: app service not found; reinstall the app")
    }
    func test_failureMessagesIdentifyRequestedOperation() {
        XCTAssertEqual(LoginItemState.failureMessage(enabling: true), "Launch at Login: could not enable; check installation and Login Items in System Settings")
        XCTAssertEqual(LoginItemState.failureMessage(enabling: false), "Launch at Login: could not disable; check Login Items in System Settings")
    }
}
